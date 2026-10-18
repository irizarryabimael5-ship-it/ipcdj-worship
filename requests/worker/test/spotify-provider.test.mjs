import {test} from "node:test";
import assert from "node:assert/strict";
import {lookupSpotifyCandidate,SpotifyLookupError} from "../src/spotify-provider.js";
const id="4DYvC8ozC0SF3SoyIpkuiY";
const source={title:"Háblame de Cerca",artist:"Grupo Grace & Kairo Worship",
 link:"https://open.spotify.com/track/"+id};
const env={APP_ENV:"staging",SPOTIFY_CLIENT_ID:"a".repeat(32),SPOTIFY_CLIENT_SECRET:"b".repeat(32)};
const official={id,type:"track",name:"Háblame de Cerca",explicit:false,is_playable:true,
 artists:[{name:"Grupo Grace"},{name:"Kairo Worship"}],
 external_urls:{spotify:source.link},
 album:{name:"Háblame de Cerca",images:[{width:640,url:"https://i.scdn.co/image/original-cover"}]},
 preview_url:null};
const json=(d,status=200)=>new Response(JSON.stringify(d),{status,headers:{"Content-Type":"application/json"}});
test("missing OAuth secrets block all network requests",async()=>{
 let calls=0;await assert.rejects(
  lookupSpotifyCandidate(source,{APP_ENV:"staging"},{fetchImpl:async()=>{calls++}}),
  e=>e instanceof SpotifyLookupError&&e.code==="SPOTIFY_NOT_CONFIGURED");
 assert.equal(calls,0);
});
test("production is disallowed even if credentials are present",async()=>{
 await assert.rejects(lookupSpotifyCandidate(source,{...env,APP_ENV:"production"}),
  e=>e.code==="SPOTIFY_ENVIRONMENT_FORBIDDEN");
});
test("official 2-call Spotify lookup checks ID and keeps candidate PRIVATE",async()=>{
 let calls=0;
 const f=async(url,opts)=>{
  calls++;
  assert.equal(opts.redirect,"error");
  assert.ok(opts.signal);
  if(calls===1){
   assert.equal(url,"https://accounts.spotify.com/api/token");
   assert.equal(opts.method,"POST");
   assert.ok(opts.headers.Authorization.startsWith("Basic "));
   return json({access_token:"opaque-test-token",token_type:"Bearer"});
  }
  assert.equal(url,"https://api.spotify.com/v1/tracks/"+id+"?market=US");
  assert.equal(opts.headers.Authorization,"Bearer opaque-test-token");
  return json(official);
 };
 const candidate=await lookupSpotifyCandidate(source,env,{fetchImpl:f});
 assert.equal(calls,2);
 assert.equal(candidate.decision,"high_confidence_candidate");
 assert.equal(candidate.publicationEligible,false);
 assert.equal(candidate.match.spotifyTrackId,id);
 assert.equal(candidate.match.previewAvailable,false);
 assert.equal(candidate.match.artworkUrl,"https://i.scdn.co/image/original-cover");
});
test("wrong recording requires manual review, never best-guess substitute",async()=>{
 let n=0;const f=async()=>{n++;return n===1?json({access_token:"token-123456",token_type:"Bearer"}):
   json({...official,name:"Wrong Recording"})};
 const r=await lookupSpotifyCandidate(source,env,{fetchImpl:f});
 assert.equal(r.decision,"manual_review");
 assert.equal(r.match,null);
});
test("Spotify quota 429 is retryable without emitting secrets",async()=>{
 await assert.rejects(lookupSpotifyCandidate(source,env,{
  fetchImpl:async()=>json({error:{reason:"QUOTA_EXCEEDED"}},429)}),
  e=>e instanceof SpotifyLookupError&&e.code==="SPOTIFY_QUOTA_OR_RATE_LIMITED");
});
test("oversized provider payload fails closed before parsing",async()=>{
 let calls=0;
 await assert.rejects(lookupSpotifyCandidate(source,env,{fetchImpl:async()=>{calls++;
  return new Response("z".repeat(16500),{status:200});
 }}),e=>e.code==="SPOTIFY_RESPONSE_TOO_LARGE");
 assert.equal(calls,1);
});
test("provider track not found is a safe manual-review result",async()=>{
 let n=0;const f=async()=>{n++;return n===1?json({access_token:"token-123456",token_type:"Bearer"}):
  json({error:"not found"},404)};
 const r=await lookupSpotifyCandidate(source,env,{fetchImpl:f});
 assert.equal(r.decision,"manual_review");
 assert.equal(r.reason,"TRACK_ID_MISMATCH");
});
