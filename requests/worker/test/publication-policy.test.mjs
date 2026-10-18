import {test} from "node:test";
import assert from "node:assert/strict";
import {DatabaseSync} from "node:sqlite";
import {readFileSync} from "node:fs";
import {publicSong,publishVerifiedCandidates} from "../src/publication-policy.js";
const schema=readFileSync(new URL("../schema.sql",import.meta.url),"utf8");
const stamp="2026-10-18T01:00:00.000Z";
function fixture(status="pending",overrides={}){
 const sql=new DatabaseSync(":memory:");sql.exec("PRAGMA foreign_keys=ON;");sql.exec(schema);
 const id="c9692e06-7d2c-4d0d-bce9-2b79f2c24304";
 const candidate={itunesTrackId:"1884087646",title:"Háblame de Cerca",artist:"Grupo Grace & Kairo Worship",
 source:"apple_itunes_search",storeUrl:"https://music.apple.com/us/song/hablame-de-cerca/1884087646",
 artworkUrl:"https://is1-ssl.mzstatic.com/image/100x100bb.jpg",
 previewUrl:"https://audio-ssl.itunes.apple.com/sample.m4a",
 requiresStoreBadge:true,requiresPreviewAttribution:"provided courtesy of iTunes",
 previewStreamingOnly:true,...overrides};
 const metadata={match:{status:"matched",reason:"PROMOTIONAL_DISPLAY_REQUIREMENTS_PENDING",candidate},PRIVATE_NOTE:"must-not-leak"};
 sql.prepare("INSERT INTO song_requests(id,canonical_key,title,artist,status,created_at,last_requested_at,updated_at,metadata_json) VALUES(?,?,?,?,?,?,?,?,?)").run(
 id,id,"Háblame de Cerca","Grupo Grace & Kairo Worship",status,stamp,stamp,stamp,JSON.stringify(metadata));
 const prepare=(query,args=[])=>({bind:(...a)=>prepare(query,a),
  all:async()=>({results:sql.prepare(query).all(...args)}),
  run:async()=>sql.prepare(query).run(...args)});
 return {DB:{prepare:query=>prepare(query)},row:()=>sql.prepare("SELECT * FROM song_requests").get(),
  audit:()=>sql.prepare("SELECT count(*) AS n FROM request_audit").get().n,close:()=>sql.close()};
}
const env=d=>({APP_ENV:"staging",PUBLICATION_ENABLED:"true",PUBLIC_PROMO_DISPLAY_CERTIFIED:"true",DB:d.DB});
const clock=()=>new Date(stamp);
test("disabled, uncertified, and nonstaging publication never changes data",async()=>{
 const d=fixture();try{
  for(const v of [{...env(d),APP_ENV:"production"},
   {...env(d),PUBLICATION_ENABLED:"false"},
   {...env(d),PUBLIC_PROMO_DISPLAY_CERTIFIED:"false"}]){
   assert.equal((await publishVerifiedCandidates(v,{clock})).enabled,false);
   assert.equal(d.row().status,"pending");
  }
 }finally{d.close()}
});
test("exact metadata is published only behind two gates with status audit",async()=>{
 const d=fixture();try{
  assert.equal((await publishVerifiedCandidates(env(d),{clock})).published,1);
  assert.equal(d.row().status,"published");assert.equal(d.row().published_at,stamp);
  assert.equal(d.audit(),1);
  const visible=publicSong(d.row());
  assert.equal(visible.status,"Solicitada");
  assert.equal(visible.metadata.promoProvider,"itunes");
  assert.equal(JSON.stringify(visible).includes("PRIVATE_NOTE"),false);
  assert.equal(JSON.stringify(visible).includes("must-not-leak"),false);
  assert.equal((await publishVerifiedCandidates(env(d),{clock})).published,0);
 }finally{d.close()}
});
test("held, rejected, approved and already published records are never auto-published",async()=>{
 for(const status of ["held","rejected","approved","published"]){
  const d=fixture(status);try{
   assert.equal((await publishVerifiedCandidates(env(d),{clock})).published,0);
   assert.equal(d.row().status,status);
  }finally{d.close()}
 }
});
test("wrong track, artist, provider and media fail closed",async()=>{
 for(const v of [{itunesTrackId:"1884087647"},{artist:"Other Singer"},
  {source:"unknown"},{artworkUrl:"https://evil.test/art.jpg"},
  {previewUrl:"http://audio-ssl.itunes.apple.com/song.mp3"},
  {previewStreamingOnly:false}]){
  const d=fixture("pending",v);try{
   assert.equal((await publishVerifiedCandidates(env(d),{clock})).published,0);
   assert.equal(d.row().status,"pending");
  }finally{d.close()}
 }
});
test("public view never serializes private candidate metadata",()=>{
 const d=fixture();try{
  const visible=publicSong(d.row());
  assert.deepEqual(visible.metadata,{});
  assert.equal(visible.artworkUrl,"");assert.equal(visible.previewUrl,"");
  assert.equal(JSON.stringify(visible).includes("match"),false);
 }finally{d.close()}
});
test("simultaneous publication workers cannot double publish",async()=>{
 const d=fixture();try{
  const [a,b]=await Promise.all([publishVerifiedCandidates(env(d),{clock}),
   publishVerifiedCandidates(env(d),{clock})]);
  assert.equal(a.published+b.published,1);assert.equal(d.audit(),1);
 }finally{d.close()}
});
