// Staging-only private-match publication policy. Never override Apple media terms.
const parse=s=>{try{const o=JSON.parse(s||"{}");return o&&typeof o==="object"&&!Array.isArray(o)?o:{}}catch(_){return {}}};
const norm=s=>String(s||"").normalize("NFKD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();
const validUrl=(s,kind)=>{
 if(typeof s!=="string"||s.length>900)return "";
 try{const u=new URL(s),h=u.hostname.toLowerCase();
  if(u.protocol!=="https:"||u.port||u.username||u.password)return "";
  if(kind==="store"&&!["music.apple.com","itunes.apple.com"].includes(h))return "";
  if(kind==="art"&&!/^is[0-9]*-ssl\.mzstatic\.com$/.test(h))return "";
  if(kind==="audio"&&!["audio-ssl.itunes.apple.com","audio.itunes.apple.com"].includes(h))return "";
  return u.href;
 }catch(_){return ""}
};
const updated=r=>Number(r?.meta?.changes??r?.changes??0)===1;
export const PROMO_CONTRACT="itunes-official-badge-stream-only-v1";
export function getVerifiedCandidate(row){
 if(!row||row.status!=="pending"||row.published_at)return null;
 const meta=parse(row.metadata_json),m=meta.match,c=m?.candidate;
 if(m?.status!=="matched"||m.reason!=="PROMOTIONAL_DISPLAY_REQUIREMENTS_PENDING"||!c)return null;
 if(c.source!=="apple_itunes_search"||c.requiresStoreBadge!==true||
    c.requiresPreviewAttribution!=="provided courtesy of iTunes"||
    c.previewStreamingOnly!==true||norm(row.title)!==norm(c.title)||
    norm(row.artist)!==norm(c.artist)||
    !/^[1-9][0-9]{3,19}$/.test(String(c.itunesTrackId||"")))return null;
 const storeUrl=validUrl(c.storeUrl,"store"),artworkUrl=validUrl(c.artworkUrl,"art"),
   previewUrl=validUrl(c.previewUrl,"audio");
 if(!storeUrl||!artworkUrl||!previewUrl)return null;
 const u=new URL(storeUrl),pathId=u.pathname.includes("/song/")?u.pathname.match(/\/([0-9]{4,20})\/?$/)?.[1]:"";
 const statedId=u.searchParams.get("i")||pathId||"";
 if(statedId&&statedId!==String(c.itunesTrackId))return null;
 return {trackId:String(c.itunesTrackId),storeUrl,artworkUrl,previewUrl};
}
export function publicSong(row){
 // Private match, admin review, comments and operational metadata NEVER leak.
 const p=parse(row.metadata_json).publicDisplay||{};
 const eligible=p.contract===PROMO_CONTRACT;
 const store=eligible?validUrl(p.storeUrl,"store"):"";
 const art=store?validUrl(row.artwork_url,"art"):"";
 const audio=art?validUrl(row.preview_url,"audio"):"";
 const ok=!!audio;
 return {id:row.id,title:row.title,artist:row.artist,
   artworkUrl:ok?art:"",previewUrl:ok?audio:"",
   requestCount:row.request_count,publishedAt:row.published_at,
   metadata:ok?{storeUrl:store,promoProvider:"itunes",
     promoContract:PROMO_CONTRACT,promoAttribution:"provided courtesy of iTunes"}:{},
   status:"Solicitada"};
}
export async function publishVerifiedCandidates(env,{clock=()=>new Date()}={}){
 const report={enabled:false,checked:0,published:0};
 if(env?.APP_ENV!=="staging"||env?.PUBLICATION_ENABLED!=="true"||
    env?.PUBLIC_PROMO_DISPLAY_CERTIFIED!=="true"||!env?.DB)return report;
 report.enabled=true;
 const rows=(await env.DB.prepare(
  "SELECT id,title,artist,status,published_at,metadata_json FROM song_requests "+
  "WHERE status='pending' AND published_at IS NULL ORDER BY created_at ASC LIMIT 20"
 ).all()).results||[];
 for(const row of rows){
  if(report.checked>=2)break;
  const c=getVerifiedCandidate(row);if(!c)continue;
  report.checked++;
  const at=clock().toISOString(),meta=parse(row.metadata_json);
  const raw=JSON.stringify({...meta,publicDisplay:{
   contract:PROMO_CONTRACT,trackId:c.trackId,storeUrl:c.storeUrl
  }});
  const out=await env.DB.prepare(
   "UPDATE song_requests SET status='published',published_at=?,updated_at=?,"+
   "artwork_url=?,preview_url=?,metadata_json=? "+
   "WHERE id=? AND status='pending' AND published_at IS NULL AND metadata_json=?"
  ).bind(at,at,c.artworkUrl,c.previewUrl,raw,row.id,row.metadata_json).run();
  if(updated(out))report.published++;
 }
 return report;
}
