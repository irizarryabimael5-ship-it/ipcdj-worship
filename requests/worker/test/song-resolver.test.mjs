import {test} from "node:test";
import assert from "node:assert/strict";
import {evaluateAppleCandidates as find} from "../src/song-resolver.js";
const song=(overrides={})=>({
 wrapperType:"track",kind:"song",trackId:1884087646,
 trackName:"Háblame de Cerca",artistName:"Grupo Grace & Kairo Worship",
 collectionName:"Háblame de Cerca",trackExplicitness:"notExplicit",
 trackViewUrl:"https://music.apple.com/us/song/hablame-de-cerca/1884087646",
 artworkUrl100:"https://is1-ssl.mzstatic.com/image/100x100bb.jpg",
 previewUrl:"https://audio-ssl.itunes.apple.com/itunes-assets/preview.m4a",
 ...overrides
});
const req=(overrides={})=>({
 title:"Háblame de Cerca",artist:"Grupo Grace & Kairo Worship",...overrides
});
test("high confidence candidate never means publication permission",()=>{
 const r=find(req(),[song()]);
 assert.equal(r.decision,"high_confidence_candidate");
 assert.equal(r.publicationEligible,false);
 assert.equal(r.match.itunesTrackId,"1884087646");
 assert.equal(r.match.previewStreamingOnly,true);
 assert.equal(r.match.requiresStoreBadge,true);
});
test("diacritics/case are normalized; wrong collaboration is refused",()=>{
 assert.equal(find(req({title:"HABLAME DE CERCA"}),[song()]).decision,"high_confidence_candidate");
 assert.equal(find(req({artist:"Grupo Grace"}),[song()]).decision,"manual_review");
});
test("distinct recordings and live albums are manual review",()=>{
 assert.equal(find(req(),[song(),song({trackId:1884087647})]).reason,"AMBIGUOUS_RECORDING");
 assert.equal(find(req(),[song({collectionName:"Grabado En Vivo"})]).decision,"manual_review");
});
test("links to other providers cannot silently identify Apple versions",()=>{
 assert.equal(find(req({link:"https://open.spotify.com/track/example"}),[song()]).decision,"manual_review");
 assert.equal(find(req({link:"https://music.apple.com/us/song/hablame-de-cerca/1884087646"}),[song()]).decision,"high_confidence_candidate");
 assert.equal(find(req({link:"https://music.apple.com/us/song/wrong/1884087647"}),[song()]).decision,"manual_review");
});
test("wrong names, explicit, and unsafe media require review",()=>{
 for(const change of [
  {artistName:"Another Artist"},{trackName:"Háblame de Cerca (cover)"},
  {trackExplicitness:"explicit"},{previewUrl:"https://example.net/clip.mp3"},
  {artworkUrl100:"http://is1-ssl.mzstatic.com/image.jpg"}]){
  assert.equal(find(req(),[song(change)]).decision,"manual_review");
 }
});
test("no guessing from missing or malformed provider results",()=>{
 assert.equal(find(req(),null).decision,"manual_review");
 assert.equal(find({artist:"A"},[song()]).reason,"INVALID_REQUEST");
});
