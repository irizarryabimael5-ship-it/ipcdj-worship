import {test} from "node:test";
import assert from "node:assert/strict";
import {DatabaseSync} from "node:sqlite";
import {readFileSync} from "node:fs";
import {processPendingSongMatches as process} from "../src/match-pipeline.js";
const schema=readFileSync(new URL("../schema.sql",import.meta.url),"utf8");
const now="2026-10-18T00:00:00.000Z",clock=()=>new Date(now);
const song=(override={})=>({
  wrapperType:"track",kind:"song",trackId:1884087646,
  trackName:"Háblame de Cerca",artistName:"Grupo Grace & Kairo Worship",
  collectionName:"Háblame de Cerca",trackExplicitness:"notExplicit",
  trackViewUrl:"https://music.apple.com/us/song/hablame-de-cerca/1884087646",
  artworkUrl100:"https://is1-ssl.mzstatic.com/image/100x100bb.jpg",
  previewUrl:"https://audio-ssl.itunes.apple.com/itunes-assets/preview.m4a",...override
});
function setup(link=""){
  const sql=new DatabaseSync(":memory:");
  sql.exec("PRAGMA foreign_keys=ON;");sql.exec(schema);
  const prepare=(query,args=[])=>({
    bind:(...a)=>prepare(query,a),
    run:async()=>sql.prepare(query).run(...args),
    all:async()=>({results:sql.prepare(query).all(...args)})
  });
  sql.prepare("INSERT INTO song_requests(id,canonical_key,title,artist,link_url,created_at,last_requested_at,updated_at) VALUES(?,?,?,?,?,?,?,?)").run(
    "c9692e06-7d2c-4d0d-bce9-2b79f2c24304",
    "hablame de cerca|grupo grace kairo worship","Háblame de Cerca",
    "Grupo Grace & Kairo Worship",link,now,now,now);
  return {
    DB:{prepare:query=>prepare(query)},
    row:()=>sql.prepare("SELECT * FROM song_requests").get(),
    audit:()=>sql.prepare("SELECT COUNT(*) AS n FROM request_audit").get().n,
    close:()=>sql.close()
  };
}
const response=results=>new Response(JSON.stringify({results}),{
  status:200,headers:{"Content-Type":"application/json"}});
const env=db=>({APP_ENV:"staging",MATCH_PENDING_ENABLED:"true",DB:db.DB});
test("matching defaults off and is staging-only",async()=>{
  const d=setup();try{
    let calls=0;const fetchImpl=async()=>{calls++;return response([song()])};
    assert.equal((await process({...env(d),MATCH_PENDING_ENABLED:"false"},{fetchImpl,clock})).checked,0);
    assert.equal((await process({...env(d),APP_ENV:"production"},{fetchImpl,clock})).checked,0);
    assert.equal(calls,0);assert.equal(d.row().status,"pending");
  }finally{d.close()}
});
test("one exact version stores private candidate without publication or downloads",async()=>{
  const d=setup();try{
    let calls=0;const fetchImpl=async u=>{calls++;assert.ok(u.startsWith("https://itunes.apple.com/search?"));return response([song()])};
    const result=await process(env(d),{fetchImpl,clock});
    assert.equal(result.matched,1);assert.equal(d.row().status,"pending");
    assert.equal(d.row().published_at,null);assert.equal(d.row().artwork_url,"");
    assert.equal(d.row().preview_url,"");
    const m=JSON.parse(d.row().metadata_json).match;
    assert.equal(m.status,"matched");assert.equal(m.candidate.itunesTrackId,"1884087646");
    assert.equal(m.candidate.requiresStoreBadge,true);
    await process(env(d),{fetchImpl,clock});assert.equal(calls,1);
  }finally{d.close()}
});
test("ambiguous recordings are held with database audit",async()=>{
  const d=setup();try{
    const result=await process(env(d),{fetchImpl:async()=>response([song(),song({trackId:1884087647})]),clock});
    assert.equal(result.held,1);assert.equal(d.row().status,"held");
    assert.equal(d.audit(),1);
    assert.equal(JSON.parse(d.row().metadata_json).match.reason,"AMBIGUOUS_RECORDING");
  }finally{d.close()}
});
test("Spotify source without secret credentials remains private and retries, no Apple requests",async()=>{
  const d=setup("https://open.spotify.com/track/4DYvC8ozC0SF3SoyIpkuiY");try{
    let calls=0;const out=await process(env(d),{fetchImpl:async()=>{calls++;return response([])},clock});
    assert.equal(out.held,0);assert.equal(out.retries,1);assert.equal(calls,0);
    assert.equal(d.row().status,"pending");
    assert.equal(JSON.parse(d.row().metadata_json).match.status,"retry");
  }finally{d.close()}
});
test("official Spotify exact track can be stored privately without publishing",async()=>{
  const d=setup("https://open.spotify.com/track/4DYvC8ozC0SF3SoyIpkuiY");try{
    const vars={...env(d),SPOTIFY_CLIENT_ID:"a".repeat(32),SPOTIFY_CLIENT_SECRET:"b".repeat(32)};
    const url="https://open.spotify.com/track/4DYvC8ozC0SF3SoyIpkuiY";
    let calls=0;
    const fetchImpl=async (urlString)=>{
      calls++;
      if(calls===1){assert.equal(urlString,"https://accounts.spotify.com/api/token");
        return new Response(JSON.stringify({access_token:"testing-bearer-token",token_type:"Bearer"}),{status:200});}
      assert.equal(urlString,"https://api.spotify.com/v1/tracks/4DYvC8ozC0SF3SoyIpkuiY?market=US");
      return new Response(JSON.stringify({type:"track",id:"4DYvC8ozC0SF3SoyIpkuiY",
        name:"Háblame de Cerca",artists:[{name:"Grupo Grace"},{name:"Kairo Worship"}],
        explicit:false,is_playable:true,external_urls:{spotify:url},
        album:{name:"Háblame de Cerca",images:[{width:640,url:"https://i.scdn.co/image/original-art"}]},
        preview_url:null}),{status:200});
    };
    const out=await process(vars,{fetchImpl,clock});
    assert.equal(out.matched,1);assert.equal(calls,2);
    assert.equal(d.row().status,"pending");assert.equal(d.row().published_at,null);
    assert.equal(d.row().artwork_url,"");assert.equal(d.row().preview_url,"");
    assert.equal(JSON.parse(d.row().metadata_json).match.candidate.source,"spotify_official_track_api");
  }finally{d.close()}
});
test("failed provider lookup backs off without a public side effect",async()=>{
  const d=setup();try{
    let calls=0;const fetchImpl=async()=>{calls++;throw Error("network")};
    const first=await process(env(d),{fetchImpl,clock});
    assert.equal(first.retries,1);assert.equal(d.row().status,"pending");
    assert.ok(JSON.parse(d.row().metadata_json).match.nextAt>now);
    await process(env(d),{fetchImpl,clock});
    assert.equal(calls,1);
  }finally{d.close()}
});
test("concurrent Cron invocations can claim a song only once",async()=>{
  const d=setup();try{
    let calls=0;const fetchImpl=async()=>{calls++;return response([song()])};
    await Promise.all([process(env(d),{fetchImpl,clock}),process(env(d),{fetchImpl,clock})]);
    assert.equal(calls,1);assert.equal(d.row().status,"pending");
  }finally{d.close()}
});
