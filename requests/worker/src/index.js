import {processEmailOutbox} from "./email-outbox.js";
import {processPendingSongMatches} from "./match-pipeline.js";
import {runOneTimeEmailProbe,probeAllowed} from "./email-probe.js";
// IPCDJ Worship — Song Requests, isolated from the existing Web Push Worker.
// Stage 1: durable intake, abuse controls, private review, and email outbox.
// Automatic media matching, outbox delivery and public forms are deliberately gated.
const MAX_BYTES=10000;
const WINDOW_MS=60*60*1000;
const MAX_REQUESTS_PER_WINDOW=5;
const SITEVERIFY="https://challenges.cloudflare.com/turnstile/v0/siteverify";
const json=(body,status=200,headers={})=>new Response(JSON.stringify(body),{
  status,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","X-Content-Type-Options":"nosniff",...headers}
});
const error=(code,status,headers={})=>json({ok:false,error:code},status,headers);
const nowIso=()=>new Date().toISOString();
const clean=(value,max)=>{
  if(typeof value!=="string")return "";
  const text=value.normalize("NFC").replace(/[\u0000-\u001F\u007F]/g," ").replace(/\s+/g," ").trim();
  return text.length<=max?text:"";
};
const normalizeKey=text=>text.normalize("NFKD").replace(/[\u0300-\u036f]/g,"")
  .toLocaleLowerCase("en-US").replace(/[^a-z0-9]+/g," ").trim();
const keyOf=(title,artist)=>normalizeKey(title)+"|"+normalizeKey(artist);
const sha256=async(value)=>{
  const buffer=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
  return [...new Uint8Array(buffer)].map(b=>b.toString(16).padStart(2,"0")).join("");
};
const configOrigin=env=>String(env.SITE_ORIGIN||"");
const cors=(origin,env)=>origin&&origin===configOrigin(env)?{
  "Access-Control-Allow-Origin":origin,
  "Access-Control-Allow-Headers":"Content-Type,Authorization",
  "Access-Control-Allow-Methods":"GET,POST,OPTIONS",
  "Access-Control-Max-Age":"600",
  "Vary":"Origin"
}:{"Vary":"Origin"};
function safeLink(input){
  if(input==null||input==="")return "";
  if(typeof input!=="string"||input.length>500)return null;
  try{
    const u=new URL(input);
    if(u.protocol!=="https:"||u.username||u.password||u.port)return null;
    const h=u.hostname.toLowerCase();
    const allowed=["open.spotify.com","music.apple.com","music.youtube.com","www.youtube.com","youtube.com","youtu.be"];
    if(!allowed.includes(h))return null;
    if(h==="open.spotify.com"&&!/^\/(?:intl-[a-z]+\/)?track\/[a-zA-Z0-9]+\/?$/.test(u.pathname))return null;
    if(h==="music.apple.com"&&!/\/(?:song\/|album\/)/.test(u.pathname))return null;
    if(["youtube.com","www.youtube.com","music.youtube.com"].includes(h)&&u.pathname!=="/watch")return null;
    if(h==="youtu.be"&&!/^\/[a-zA-Z0-9_-]{6,}$/.test(u.pathname))return null;
    return u.origin+u.pathname+(u.search||""); // anchors aren't significant
  }catch(_){return null;}
}
function parseRequestBody(obj){
  if(!obj||Array.isArray(obj)||typeof obj!=="object")return null;
  const title=clean(obj.title,120),artist=clean(obj.artist,120),comment=clean(obj.comment??"",350);
  const link=safeLink(obj.link??"");
  const token=typeof obj.turnstileToken==="string"?obj.turnstileToken:"";
  const idempotencyKey=typeof obj.idempotencyKey==="string"?obj.idempotencyKey.toLowerCase():"";
  if(!title||!artist||!normalizeKey(title)||!normalizeKey(artist)||link===null)return null;
  if((obj.comment??"")!==""&&!comment)return null;
  if(!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(idempotencyKey))return null;
  if(token.length<4||token.length>2048)return null;
  return {title,artist,comment,link,token,idempotencyKey,canonical:keyOf(title,artist)};
}
async function readSmallJson(request){
  if(!/application\/json(?:;|$)/i.test(request.headers.get("content-type")||""))return null;
  const reported=Number(request.headers.get("content-length")||"0");
  if(reported>MAX_BYTES)return null;
  if(!request.body)return null;
  // Never buffer an unbounded request merely because Content-Length was omitted.
  const reader=request.body.getReader(),chunks=[];
  let size=0;
  try{
    while(true){
      const {value,done}=await reader.read();
      if(done)break;
      size+=value.byteLength;
      if(size>MAX_BYTES){
        try{await reader.cancel()}catch(_){}
        return null;
      }
      chunks.push(value);
    }
  }finally{reader.releaseLock();}
  const bytes=new Uint8Array(size);
  let position=0;
  for(const chunk of chunks){bytes.set(chunk,position);position+=chunk.byteLength;}
  try{
    const body=new TextDecoder("utf-8",{fatal:true}).decode(bytes);
    return JSON.parse(body);
  }catch(_){return null}
}
const adminAuthorized=(req,env)=>{
  const token=env.ADMIN_TOKEN;
  return typeof token==="string"&&token.length>=32&&
    req.headers.get("authorization")==="Bearer "+token;
};
async function verifyChallenge(token,ip,env){
  if(!env.TURNSTILE_SECRET||!env.TURNSTILE_EXPECTED_HOSTNAME)return false;
  const params=new URLSearchParams({secret:env.TURNSTILE_SECRET,response:token});
  if(ip)params.set("remoteip",ip);
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),5000);
  try{
    const response=await fetch(SITEVERIFY,{
      method:"POST",body:params,
      headers:{"Content-Type":"application/x-www-form-urlencoded"},
      signal:controller.signal
    });
    if(!response.ok)return false;
    const data=await response.json();
    return data.success===true &&
      data.hostname===env.TURNSTILE_EXPECTED_HOSTNAME &&
      data.action==="song_request";
  }catch(_){return false}finally{clearTimeout(timer)}
}
function adminCors(request,env){
  const origin=request.headers.get("origin")||"";
  return !origin||origin===configOrigin(env)?cors(origin,env):null;
}
async function submit(req,env,headers){
  if(env.INGEST_ENABLED!=="true")return error("intake-unavailable",503,headers);
  if(!env.DB||!env.TURNSTILE_SECRET||!env.TURNSTILE_EXPECTED_HOSTNAME||
     !env.IP_HASH_SALT||env.IP_HASH_SALT.length<32)return error("intake-unconfigured",503,headers);
  const ip=req.headers.get("cf-connecting-ip");
  if(!ip||ip.length>100)return error("request-origin-unavailable",403,headers);
  const values=parseRequestBody(await readSmallJson(req));
  if(!values)return error("invalid-request",400,headers);
  const {canonical,title,artist,comment,link,idempotencyKey,token}=values;
  const contentHash=await sha256(JSON.stringify([canonical,link,comment]));
  const idemHash=await sha256("idem:"+env.IP_HASH_SALT+":"+idempotencyKey);
  const prior=await env.DB.prepare("SELECT request_id,payload_hash FROM request_submissions WHERE idempotency_hash=?")
    .bind(idemHash).first();
  if(prior){
    if(prior.payload_hash!==contentHash)return error("idempotency-conflict",409,headers);
    return json({ok:true,requestId:prior.request_id,replayed:true,review:"pending"},200,headers);
  }
  const ipHash=await sha256("ip:"+env.IP_HASH_SALT+":"+ip);
  const now=nowIso(),start=new Date(Date.now()-WINDOW_MS).toISOString();
  const recent=await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM request_rate_events WHERE ip_hash=? AND created_at>=?"
  ).bind(ipHash,start).first();
  if(Number(recent?.n||0)>=MAX_REQUESTS_PER_WINDOW){
    return error("rate-limited",429,{"Retry-After":"3600",...headers});
  }
  if(!await verifyChallenge(token,ip,env))return error("verification-failed",403,headers);
  const songId=crypto.randomUUID();
  const eventId=crypto.randomUUID();
  const eventRateId=crypto.randomUUID();
  try{
    // D1 batch is atomic. Concurrent duplicate titles update a single song,
    // while request submissions and notification outbox remain immutable.
    await env.DB.batch([
      env.DB.prepare(
        "INSERT INTO song_requests(id,canonical_key,title,artist,link_url,comment,status,request_count,created_at,last_requested_at,updated_at) "+
        "VALUES(?,?,?,?,?,?,'pending',1,?,?,?) "+
        "ON CONFLICT(canonical_key) DO UPDATE SET request_count=request_count+1,last_requested_at=excluded.last_requested_at,updated_at=excluded.updated_at"
      ).bind(songId,canonical,title,artist,link,comment,now,now,now),
      env.DB.prepare(
        "INSERT INTO request_submissions(idempotency_hash,payload_hash,request_id,created_at) "+
        "SELECT ?,?,id,? FROM song_requests WHERE canonical_key=?"
      ).bind(idemHash,contentHash,now,canonical),
      env.DB.prepare(
        "INSERT INTO request_outbox(id,request_id,event_type,status,attempts,created_at,next_attempt_at) "+
        "SELECT ?,id,'new_submission','pending',0,?,? FROM song_requests WHERE canonical_key=?"
      ).bind(eventId,now,now,canonical),
      env.DB.prepare(
        "INSERT INTO request_rate_events(id,ip_hash,created_at) VALUES(?,?,?)"
      ).bind(eventRateId,ipHash,now)
    ]);
  }catch(writeError){
    // A database trigger also enforces this limit atomically across concurrent requests.
    // D1 rolls back the full request/outbox transaction if the insert is denied.
    if(String(writeError?.message||writeError).includes("rate-limited")){
      return error("rate-limited",429,{"Retry-After":"3600",...headers});
    }
    // An idempotency race must not double-count or emit a duplicate event.
    const replay=await env.DB.prepare("SELECT request_id,payload_hash FROM request_submissions WHERE idempotency_hash=?")
      .bind(idemHash).first();
    if(replay&&replay.payload_hash===contentHash){
      return json({ok:true,requestId:replay.request_id,replayed:true,review:"pending"},200,headers);
    }
    return error(replay?"idempotency-conflict":"storage-error",replay?409:503,headers);
  }
  const saved=await env.DB.prepare("SELECT id FROM song_requests WHERE canonical_key=?")
    .bind(canonical).first();
  return json({ok:true,requestId:saved.id,replayed:false,review:"pending"},202,headers);
}
async function publicList(env,headers){
  if(!env.DB)return error("feed-unavailable",503,headers);
  const rows=(await env.DB.prepare(
    "SELECT id,title,artist,artwork_url,preview_url,metadata_json,request_count,published_at "+
    "FROM song_requests WHERE status='published' ORDER BY published_at DESC,id ASC LIMIT 100"
  ).all()).results||[];
  return json({ok:true,songs:rows.map(row=>({
    id:row.id,title:row.title,artist:row.artist,
    artworkUrl:row.artwork_url||"",previewUrl:row.preview_url||"",
    requestCount:row.request_count,publishedAt:row.published_at,
    metadata:JSON.parse(row.metadata_json||"{}"),status:"Solicitada"
  }))},200,{"Cache-Control":"public, max-age=30",...headers});
}
async function adminList(req,env,headers){
  if(!adminAuthorized(req,env))return error("unauthorized",401,headers);
  if(!env.DB)return error("storage-unavailable",503,headers);
  const url=new URL(req.url);
  const filter=url.searchParams.get("status")||"all";
  const allowed=["all","pending","held","approved","rejected","published"];
  if(!allowed.includes(filter))return error("invalid-status",400,headers);
  const rows=(await (filter==="all"
    ?env.DB.prepare("SELECT * FROM song_requests ORDER BY last_requested_at DESC,id ASC LIMIT 100")
    :env.DB.prepare("SELECT * FROM song_requests WHERE status=? ORDER BY last_requested_at DESC,id ASC LIMIT 100").bind(filter)
  ).all()).results||[];
  return json({ok:true,requests:rows},200,headers);
}
async function review(req,env,id,headers){
  if(!adminAuthorized(req,env))return error("unauthorized",401,headers);
  if(!env.DB)return error("storage-unavailable",503,headers);
  if(!/^[0-9a-f]{8}-[0-9a-f-]{27,}$/.test(id))return error("invalid-id",400,headers);
  const body=await readSmallJson(req);
  const action=body?.action;
  const decisions={approve:"approved",hold:"held",reject:"rejected"};
  if(!Object.prototype.hasOwnProperty.call(decisions,action))return error("invalid-action",400,headers);
  const existing=await env.DB.prepare("SELECT id,status FROM song_requests WHERE id=?").bind(id).first();
  if(!existing)return error("not-found",404,headers);
  if(existing.status==="published")return error("published-lock",409,headers);
  const status=decisions[action],now=nowIso();
  if(status===existing.status)return json({ok:true,requestId:id,status,unchanged:true},200,headers);
  // Compare-and-swap rejects overlapping moderation. An SQLite trigger writes
  // the audit event from the actual old/new row, never stale application state.
  const result=await env.DB.prepare(
    "UPDATE song_requests SET status=?,updated_at=? WHERE id=? AND status=?"
  ).bind(status,now,id,existing.status).run();
  const changed=Number(result?.meta?.changes??result?.changes??0);
  if(changed!==1)return error("review-conflict",409,headers);
  return json({ok:true,requestId:id,status},200,headers);
}
export default {
  async fetch(req,env){
    const url=new URL(req.url),origin=req.headers.get("origin")||"";
    const headers=cors(origin,env);
    if(origin&&origin!==configOrigin(env))return error("origin-not-allowed",403,headers);
    if(req.method==="OPTIONS")return new Response(null,{status:204,headers:{
      ...headers,"Access-Control-Allow-Origin":origin||"null"
    }});
    if(url.pathname==="/health"&&req.method==="GET")return json({
      ok:true,service:"ipcdj-song-requests",environment:env.APP_ENV||"unconfigured",
      intakeEnabled:env.INGEST_ENABLED==="true",storageConfigured:!!env.DB,
      notificationsEnabled:false,publicationEnabled:false
    },200,headers);
    // Fail closed if a Worker is accidentally launched outside the staging environment.
    if(env.APP_ENV!=="staging")return error("environment-not-enabled",503,headers);
    if(url.pathname==="/v1/requests"&&req.method==="GET")return publicList(env,headers);
    if(url.pathname==="/v1/requests"&&req.method==="POST"){
      if(origin!==configOrigin(env))return error("origin-required",403,headers);
      return submit(req,env,headers);
    }
    if(url.pathname==="/v1/admin/requests"&&req.method==="GET"){
      if(!adminCors(req,env))return error("origin-not-allowed",403,headers);
      return adminList(req,env,headers);
    }
    const match=url.pathname.match(/^\/v1\/admin\/requests\/([^/]+)\/review$/);
    if(match&&req.method==="POST"){
      if(!adminCors(req,env))return error("origin-not-allowed",403,headers);
      return review(req,env,match[1],headers);
    }
    return error("not-found",404,headers);
  },
  async scheduled(_event,env,ctx){
    // Private Cloudflare Cron handler, not exposed as an HTTP route.
    // No send occurs until EMAIL_NOTIFICATIONS_ENABLED is explicitly enabled
    // and the Email Service binding + verified sender are present.
    if(env.APP_ENV!=="staging")return;
    if(probeAllowed(env)){
      const once=runOneTimeEmailProbe(env);
      if(ctx&&typeof ctx.waitUntil==="function")ctx.waitUntil(once);
      else await once;
      return;
    }
    // Matching never enables public intake, email, or publication by itself.
    const jobs=[];
    if(env.EMAIL_NOTIFICATIONS_ENABLED==="true")jobs.push(processEmailOutbox(env));
    if(env.MATCH_PENDING_ENABLED==="true")jobs.push(processPendingSongMatches(env));
    if(!jobs.length)return;
    const task=Promise.all(jobs);
    if(ctx&&typeof ctx.waitUntil==="function")ctx.waitUntil(task);
    else await task;
  }
};
