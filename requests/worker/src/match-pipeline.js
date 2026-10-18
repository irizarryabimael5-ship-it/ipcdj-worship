// IPCDJ Worship: private Staging metadata enrichment, not publication.
import {evaluateAppleCandidates} from "./song-resolver.js";
const MAX_PER_TICK=2, MAX_BYTES=262144, LEASE_MS=10*60*1000;
const changed=r=>Number(r?.meta?.changes??r?.changes??0)===1;
const plus=(at,ms)=>new Date(at.getTime()+ms).toISOString();
const read=raw=>{
  try{const m=JSON.parse(raw||"{}");return m&&typeof m==="object"&&!Array.isArray(m)?m:{}}
  catch(_){return {}}
};
function due(meta,at){
  const m=meta.match;
  return !m||(m.status!=="matched"&&(!m.nextAt||m.nextAt<=at));
}
async function search(request,fetchImpl){
  const query=new URLSearchParams({term:request.title+" "+request.artist,
    country:"US",media:"music",entity:"song",limit:"20"});
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),6000);
  try{
    const res=await fetchImpl("https://itunes.apple.com/search?"+query,{
      signal:controller.signal,headers:{Accept:"application/json"},redirect:"error"
    });
    if(!res?.ok||Number(res.headers?.get("content-length")||0)>MAX_BYTES)
      throw new Error("PROVIDER_UNAVAILABLE");
    const text=await res.text();
    if(text.length>MAX_BYTES)throw new Error("PROVIDER_TOO_LARGE");
    const json=JSON.parse(text);
    if(!Array.isArray(json?.results)||json.results.length>100)
      throw new Error("PROVIDER_MALFORMED");
    return json.results;
  }finally{clearTimeout(timer)}
}
export async function processPendingSongMatches(env,{fetchImpl=fetch,clock=()=>new Date()}={}){
  const stats={enabled:false,checked:0,matched:0,held:0,retries:0};
  if(env?.APP_ENV!=="staging"||env?.MATCH_PENDING_ENABLED!=="true"||!env?.DB)return stats;
  stats.enabled=true;
  const at=clock(),atIso=at.toISOString();
  const rows=(await env.DB.prepare(
    "SELECT id,title,artist,link_url,metadata_json FROM song_requests "+
    "WHERE status='pending' ORDER BY created_at ASC,id ASC LIMIT 25"
  ).all()).results||[];
  for(const row of rows){
    if(stats.checked>=MAX_PER_TICK)break;
    const original=read(row.metadata_json);
    if(!due(original,atIso))continue;
    const attempts=Math.min(12,Number(original.match?.attempts||0)+1);
    const lease={...original,match:{status:"checking",attempts,
      reason:"LOOKUP_IN_PROGRESS",nextAt:plus(at,LEASE_MS)}};
    const leaseRaw=JSON.stringify(lease);
    const claim=await env.DB.prepare(
      "UPDATE song_requests SET metadata_json=?,updated_at=? "+
      "WHERE id=? AND status='pending' AND metadata_json=?"
    ).bind(leaseRaw,atIso,row.id,row.metadata_json).run();
    if(!changed(claim))continue;
    stats.checked++;
    const request={title:row.title,artist:row.artist,link:row.link_url};
    let verdict;
    try{
      verdict=evaluateAppleCandidates(request,[]);
      if(!["CROSS_PROVIDER_LINK_REQUIRES_REVIEW","SOURCE_LINK_REQUIRES_REVIEW"].includes(verdict.reason))
        verdict=evaluateAppleCandidates(request,await search(request,fetchImpl));
    }catch(_){
      const delay=Math.min(12*60*60*1000,Math.pow(2,Math.min(attempts,8))*5*60*1000);
      const retry={...original,match:{status:"retry",attempts,
        reason:"PROVIDER_TEMPORARILY_UNAVAILABLE",nextAt:plus(clock(),delay)}};
      const saved=await env.DB.prepare(
        "UPDATE song_requests SET metadata_json=?,updated_at=? "+
        "WHERE id=? AND status='pending' AND metadata_json=?"
      ).bind(JSON.stringify(retry),clock().toISOString(),row.id,leaseRaw).run();
      if(changed(saved))stats.retries++;
      continue;
    }
    const ok=verdict.decision==="high_confidence_candidate";
    const metadata={...original,match:{
      status:ok?"matched":"manual_review",attempts,reason:verdict.reason,
      checkedAt:clock().toISOString(),...(ok?{candidate:verdict.match}:{})
    }};
    const updated=await env.DB.prepare(
      "UPDATE song_requests SET metadata_json=?,status=?,updated_at=? "+
      "WHERE id=? AND status='pending' AND metadata_json=?"
    ).bind(JSON.stringify(metadata),ok?"pending":"held",clock().toISOString(),
      row.id,leaseRaw).run();
    if(changed(updated)){if(ok)stats.matched++;else stats.held++;}
  }
  return stats;
}
