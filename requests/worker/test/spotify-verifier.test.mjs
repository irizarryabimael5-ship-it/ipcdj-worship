import {test} from "node:test";
import assert from "node:assert/strict";
import {spotifyId,evaluateSpotifyTrack} from "../src/spotify-verifier.js";
const id="4DYvC8ozC0SF3SoyIpkuiY";
const request={title:"Háblame de Cerca",artist:"Grupo Grace & Kairo Worship",link:"https://open.spotify.com/track/"+id};
const track=(x={})=>({id,type:"track",name:"Háblame de Cerca",explicit:false,is_playable:true,
 artists:[{name:"Grupo Grace"},{name:"Kairo Worship"}],
 external_urls:{spotify:"https://open.spotify.com/track/"+id},
 album:{name:"Háblame de Cerca",images:[{width:640,url:"https://i.scdn.co/image/test-cover"}]},
 preview_url:null,...x});
test("only an exact Spotify HTTPS track URL supplies an ID",()=>{
 assert.equal(spotifyId(request.link),id);
 for(const u of ["http://open.spotify.com/track/"+id,"https://other.com/track/"+id,
   "https://open.spotify.com/album/"+id,"https://open.spotify.com/track/wrong"])
  assert.equal(spotifyId(u),"");
});
test("exact official recording produces private metadata, never publication authority",()=>{
 const r=evaluateSpotifyTrack(request,track());
 assert.equal(r.decision,"high_confidence_candidate");
 assert.equal(r.publicationEligible,false);
 assert.equal(r.match.spotifyTrackId,id);
 assert.equal(r.match.previewAvailable,false);
 assert.equal(r.match.requiresSpotifyAttribution,true);
});
test("official preview is nullable and unsafe previews are refused",()=>{
 assert.equal(evaluateSpotifyTrack(request,track({preview_url:"https://p.scdn.co/mp3-preview/example.mp3"})).match.previewAvailable,true);
 assert.equal(evaluateSpotifyTrack(request,track({preview_url:"https://other.example/test.mp3"})).reason,"PREVIEW_UNTRUSTED");
});
test("wrong title, artist, source ID or playback restriction cannot pass",()=>{
 for(const x of [{id:"x".repeat(22)},{name:"Different"},{artists:[{name:"Wrong"}]},
  {explicit:true},{is_playable:false},{type:"episode"}])
  assert.equal(evaluateSpotifyTrack(request,track(x)).decision,"manual_review");
});
test("live/remastered album cannot be substituted for studio request",()=>{
 const a=track();a.album.name="Háblame de Cerca Live";assert.equal(evaluateSpotifyTrack(request,a).reason,"ALTERNATE_RECORDING");
});
test("wrong artwork origin blocks candidate",()=>{
 const a=track();a.album.images=[{width:1200,url:"https://evil.example/cover.jpg"}];
 assert.equal(evaluateSpotifyTrack(request,a).reason,"ARTWORK_MISSING");
});
