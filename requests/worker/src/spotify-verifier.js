// Source-only Spotify exact-recording proof. No public publishing rights.
const norm=s=>String(s??"").normalize("NFKD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();
const safe=(v,host)=>{
 try{const u=new URL(v);return u.protocol==="https:"&&u.hostname===host&&!u.port&&!u.username&&!u.password?u.href:""}catch(_){return ""}
};
export function spotifyId(link){
 if(typeof link!=="string"||link.length>600)return "";
 const s=safe(link,"open.spotify.com");if(!s)return "";
 const u=new URL(s),m=u.pathname.match(/^\/(?:intl-[a-z]{2}\/)?track\/([A-Za-z0-9]{22})\/?$/);
 return m?m[1]:"";
}
const verdict=(reason,match=null)=>({decision:match?"high_confidence_candidate":"manual_review",reason,publicationEligible:false,match});
export function evaluateSpotifyTrack(request,track){
 const id=spotifyId(request?.link);
 if(!id||!norm(request?.title)||!norm(request?.artist))return verdict("INVALID_SOURCE");
 if(!track||track.type!=="track"||track.id!==id)return verdict("TRACK_ID_MISMATCH");
 if(track.explicit===true||track.is_playable===false||track.restrictions?.reason)return verdict("TRACK_RESTRICTED");
 if(norm(track.name)!==norm(request.title))return verdict("TRACK_TITLE_MISMATCH");
 const artists=Array.isArray(track.artists)?track.artists.map(a=>a?.name):[];
 if(!artists.length||artists.some(a=>typeof a!=="string")||norm(artists.join(" & "))!==norm(request.artist))
  return verdict("TRACK_ARTIST_MISMATCH");
 const alternate=/\b(live|en vivo|remaster(?:ed)?|instrumental|karaoke|acoustic)\b/i;
 if(alternate.test(String(track.album?.name||""))&&!alternate.test(String(request.title||"")))
  return verdict("ALTERNATE_RECORDING");
 const official="https://open.spotify.com/track/"+id;
 if(track.external_urls?.spotify!==official)return verdict("TRACK_LINK_MISMATCH");
 const images=Array.isArray(track.album?.images)?track.album.images:[];
 const img=images.filter(i=>i&&safe(i.url,"i.scdn.co")).sort((a,b)=>Number(b.width||0)-Number(a.width||0))[0];
 if(!img)return verdict("ARTWORK_MISSING");
 const preview=track.preview_url==null?"":safe(track.preview_url,"p.scdn.co");
 if(track.preview_url&&!preview)return verdict("PREVIEW_UNTRUSTED");
 return verdict("EXACT_SPOTIFY_CANDIDATE",{
  source:"spotify_official_track_api",spotifyTrackId:id,title:track.name,
  artist:artists.join(" & "),storeUrl:official,artworkUrl:safe(img.url,"i.scdn.co"),
  previewUrl:preview,previewAvailable:!!preview,requiresSpotifyAttribution:true,
  requiresSpotifyLink:true,requiresOriginalArtwork:true,streamOnly:true
 });
}
