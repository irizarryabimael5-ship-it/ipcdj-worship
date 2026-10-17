// IPCDJ Worship — pure strict metadata-match classifier; NEVER publishes itself.
// Apple's Search API promo terms require nearby store badge, attribution and streaming.
const norm=s=>String(s??"").normalize("NFKD").replace(/[\u0300-\u036f]/g,"")
 .toLocaleLowerCase("en-US").replace(/[^a-z0-9]+/g," ").trim();
const verdict=(reason,match=null)=>({
 decision:match?"high_confidence_candidate":"manual_review",
 reason,publicationEligible:false,match
});
const allowUrl=(raw,kind)=>{
 if(typeof raw!=="string"||raw.length>900)return "";
 try{
  const u=new URL(raw),h=u.hostname.toLowerCase();
  if(u.protocol!=="https:"||u.username||u.password||u.port)return "";
  if(kind==="track"&&!["music.apple.com","itunes.apple.com"].includes(h))return "";
  if(kind==="art"&&!/^is[0-9]*-ssl\.mzstatic\.com$/.test(h))return "";
  if(kind==="preview"&&!["audio-ssl.itunes.apple.com","audio.itunes.apple.com"].includes(h))return "";
  return u.href;
 }catch(_){return ""}
};
function explicitSource(link){
 if(!link)return {kind:"none"};
 try{
  const u=new URL(link);
  if(u.protocol!=="https:"||u.username||u.password)return {kind:"unverified"};
  if(!["music.apple.com","itunes.apple.com"].includes(u.hostname))return {kind:"other-provider"};
  const id=u.searchParams.get("i")||u.pathname.match(/\/([0-9]{4,20})\/?$/)?.[1]||"";
  return /^[1-9][0-9]{3,19}$/.test(id)?{kind:"apple-track",id}:{kind:"unverified"};
 }catch(_){return {kind:"unverified"}}
}
// Fail closed on fuzzy titles, different featured artists, cover versions,
// alternate recordings and unsafe or unattributed media.
export function evaluateAppleCandidates(request,results){
 const title=norm(request?.title),artist=norm(request?.artist);
 if(!title||!artist||title.length>120||artist.length>120)return verdict("INVALID_REQUEST");
 if(!Array.isArray(results)||results.length>100)return verdict("INVALID_CATALOG_RESPONSE");
 const source=explicitSource(request?.link||request?.sourceUrl||"");
 if(source.kind==="other-provider")return verdict("CROSS_PROVIDER_LINK_REQUIRES_REVIEW");
 if(source.kind==="unverified")return verdict("SOURCE_LINK_REQUIRES_REVIEW");
 const matches=new Map();
 for(const row of results){
  if(!row||row.wrapperType!=="track"||row.kind!=="song"||
     norm(row.trackName)!==title||norm(row.artistName)!==artist||
     !Number.isSafeInteger(row.trackId)||row.trackId<=0)continue;
  if(source.kind==="apple-track"&&String(row.trackId)!==source.id)continue;
  if(row.trackExplicitness==="explicit")continue;
  const alt=/\b(live|en vivo|remaster(?:ed)?|acoustic|karaoke|instrumental)\b/i;
  if(alt.test(String(row.collectionName||""))&&!alt.test(String(request.title||"")))continue;
  const storeUrl=allowUrl(row.trackViewUrl,"track");
  const artworkUrl=allowUrl(row.artworkUrl100,"art");
  const previewUrl=allowUrl(row.previewUrl,"preview");
  if(!storeUrl||!artworkUrl||!previewUrl)continue;
  matches.set(String(row.trackId),{
   itunesTrackId:String(row.trackId),title:row.trackName,artist:row.artistName,
   storeUrl,artworkUrl,previewUrl,source:"apple_itunes_search",
   requiresStoreBadge:true,requiresPreviewAttribution:"provided courtesy of iTunes",
   previewStreamingOnly:true
  });
 }
 if(!matches.size)return verdict("NO_EXACT_COMPLIANT_CANDIDATE");
 if(matches.size!==1)return verdict("AMBIGUOUS_RECORDING");
 // Still blocked: only verified UI + moderation can authorize publication.
 return verdict("PROMOTIONAL_DISPLAY_REQUIREMENTS_PENDING",[...matches.values()][0]);
}
