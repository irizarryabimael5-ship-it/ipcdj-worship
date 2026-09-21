import { buildPushPayload } from '@block65/webcrypto-web-push';
import { buildSongNotificationPlan, renderMessage } from '../../core/planner.mjs';

const MAX_DELIVERIES_PER_RUN=40;
const MAX_ATTEMPTS=4;
const encoder=new TextEncoder();

function json(data,status=200,extraHeaders={}){
  return new Response(JSON.stringify(data),{
    status,
    headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store',...extraHeaders}
  });
}

function cors(origin,env){
  return origin===env.SITE_ORIGIN?{
    'Access-Control-Allow-Origin':origin,
    'Access-Control-Allow-Methods':'GET,POST,DELETE,OPTIONS',
    'Access-Control-Allow-Headers':'Content-Type,Authorization',
    'Access-Control-Max-Age':'86400',
    'Vary':'Origin'
  }:{};
}

function authorized(request,env){
  const auth=request.headers.get('authorization')||'';
  return !!env.ADMIN_TOKEN && auth==='Bearer '+env.ADMIN_TOKEN;
}

function sameOriginPath(value='/'){
  const input=String(value||'/').trim()||'/';
  if(!input.startsWith('/')||input.startsWith('//'))throw new Error('invalid-url');
  return input.slice(0,600);
}

function cleanManualText(value,max,label){
  const text=String(value||'').trim();
  if(!text)throw new Error(label+'-required');
  if(text.length>max)throw new Error(label+'-too-long');
  return text;
}

async function sha256(value){
  const digest=await crypto.subtle.digest('SHA-256',encoder.encode(value));
  return [...new Uint8Array(digest)].map(x=>x.toString(16).padStart(2,'0')).join('');
}

function cleanSubscription(value){
  const sub=value?.subscription||value;
  const endpoint=String(sub?.endpoint||'');
  const p256dh=String(sub?.keys?.p256dh||'');
  const auth=String(sub?.keys?.auth||'');
  if(!endpoint.startsWith('https://')||!p256dh||!auth)throw new Error('invalid-subscription');
  return {endpoint,p256dh,auth};
}

function cleanSong(song){
  const keys=['id','title','activeFrom','learningStart','learningEnd','finalStart','finalEnd','releaseDayStartAt','releaseAt','releaseDayEndAt','rolloverAt','introducedAt'];
  for(const key of keys){ if(!song?.[key])throw new Error('missing-'+key); }
  for(const key of keys.filter(k=>k!=='id'&&k!=='title')){
    if(!Number.isFinite(Date.parse(song[key])))throw new Error('invalid-'+key);
  }
  return song;
}

async function upsertSubscription(request,env){
  const origin=request.headers.get('origin')||'';
  if(origin!==env.SITE_ORIGIN)return json({error:'origin-not-allowed'},403,cors(origin,env));
  const body=await request.json();
  const sub=cleanSubscription(body);
  const id=await sha256(sub.endpoint);
  const now=new Date().toISOString();
  const sql='INSERT INTO subscriptions(id,endpoint,p256dh,auth,user_agent,language,standalone,enabled,failure_count,created_at,updated_at) '+
    'VALUES(?,?,?,?,?,?,?,?,0,?,?) '+
    'ON CONFLICT(endpoint) DO UPDATE SET p256dh=excluded.p256dh,auth=excluded.auth,user_agent=excluded.user_agent,'+
    'language=excluded.language,standalone=excluded.standalone,enabled=1,failure_count=0,updated_at=excluded.updated_at';
  await env.DB.prepare(sql).bind(
    id,sub.endpoint,sub.p256dh,sub.auth,String(body.userAgent||'').slice(0,500),
    String(body.language||'es').slice(0,20),body.standalone?1:0,1,now,now
  ).run();
  return json({ok:true,id},200,cors(origin,env));
}

async function deleteSubscription(request,env){
  const origin=request.headers.get('origin')||'';
  if(origin!==env.SITE_ORIGIN)return json({error:'origin-not-allowed'},403,cors(origin,env));
  const body=await request.json().catch(()=>({}));
  const endpoint=String(body.endpoint||'');
  if(!endpoint)return json({error:'endpoint-required'},400,cors(origin,env));
  await env.DB.prepare('UPDATE subscriptions SET enabled=0,updated_at=? WHERE endpoint=?')
    .bind(new Date().toISOString(),endpoint).run();
  return json({ok:true},200,cors(origin,env));
}

async function upsertSong(env,song,firstSeen,now){
  const sql='INSERT INTO songs(id,title,artist,active_from,learning_start,learning_end,final_start,final_end,release_day_start_at,release_at,release_day_end_at,rollover_at,introduced_at,first_seen_at,payload_json,updated_at) '+
    'VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) '+
    'ON CONFLICT(id) DO UPDATE SET title=excluded.title,artist=excluded.artist,active_from=excluded.active_from,'+
    'learning_start=excluded.learning_start,learning_end=excluded.learning_end,final_start=excluded.final_start,final_end=excluded.final_end,'+
    'release_day_start_at=excluded.release_day_start_at,release_at=excluded.release_at,release_day_end_at=excluded.release_day_end_at,'+
    'rollover_at=excluded.rollover_at,introduced_at=excluded.introduced_at,payload_json=excluded.payload_json,updated_at=excluded.updated_at';
  await env.DB.prepare(sql).bind(
    song.id,song.title,String(song.artist||''),song.activeFrom,song.learningStart,song.learningEnd,
    song.finalStart,song.finalEnd,song.releaseDayStartAt,song.releaseAt,song.releaseDayEndAt,
    song.rolloverAt,song.introducedAt,firstSeen,JSON.stringify(song),now
  ).run();
}

async function syncCatalog(request,env){
  if(!authorized(request,env))return json({error:'unauthorized'},401);
  const body=await request.json();
  const songs=Array.isArray(body)?body:body.songs;
  if(!Array.isArray(songs))return json({error:'songs-array-required'},400);
  const now=new Date().toISOString();
  let planned=0;

  for(const raw of songs){
    const song=cleanSong(raw);
    const existing=await env.DB.prepare('SELECT first_seen_at FROM songs WHERE id=?').bind(song.id).first();
    const firstSeen=existing?.first_seen_at||now;
    await upsertSong(env,song,firstSeen,now);

    await env.DB.prepare("UPDATE notification_events SET status='cancelled' WHERE source='auto' AND song_id=? AND status='pending'")
      .bind(song.id).run();

    const plan=buildSongNotificationPlan(song,{nowMs:Date.now(),firstSeenAtMs:Date.parse(firstSeen)});
    let lastVariant=-1;
    for(const event of plan){
      const msg=renderMessage(event.kind,song,event.eventKey,lastVariant);
      lastVariant=msg.variantIndex;
      const ttl=event.kind==='release_day'?14400:21600;
      const urgency=event.kind==='release_day'?'high':'normal';
      const tag=('song-'+song.id+'-'+event.kind).slice(0,32);
      const sql='INSERT INTO notification_events(event_key,kind,source,song_id,scheduled_at,title,body,url,tag,urgency,ttl_seconds,variant_index,template_version,status,created_at) '+
        "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,'pending',?) "+
        'ON CONFLICT(event_key) DO UPDATE SET title=excluded.title,body=excluded.body,url=excluded.url,tag=excluded.tag,'+
        'urgency=excluded.urgency,ttl_seconds=excluded.ttl_seconds,variant_index=excluded.variant_index,template_version=excluded.template_version,'+
        "status=CASE WHEN notification_events.status='sent' THEN 'sent' ELSE 'pending' END";
      await env.DB.prepare(sql).bind(
        event.eventKey,event.kind,'auto',song.id,event.scheduledAt,msg.title,msg.body,event.url,tag,
        urgency,ttl,msg.variantIndex,msg.templateVersion,now
      ).run();
      planned++;
    }
  }

  return json({ok:true,songs:songs.length,planned});
}

async function manualSend(request,env){
  const origin=request.headers.get('origin')||'';
  const headers=cors(origin,env);
  if(origin&&origin!==env.SITE_ORIGIN)return json({error:'origin-not-allowed'},403,headers);
  if(!authorized(request,env))return json({error:'unauthorized'},401,headers);

  try{
    const body=await request.json();
    const id=cleanManualText(body.idempotencyKey,120,'idempotencyKey')
      .replace(/[^A-Za-z0-9._:-]/g,'-');
    const title=cleanManualText(body.title,70,'title');
    const message=cleanManualText(body.body,150,'body');
    const scheduledAt=String(body.scheduledAt||new Date().toISOString());
    if(!Number.isFinite(Date.parse(scheduledAt)))return json({error:'invalid-scheduledAt'},400,headers);

    const now=new Date().toISOString();
    const eventKey='manual:'+id;
    const tag=String(body.tag||('manual-'+id)).replace(/[^A-Za-z0-9_-]/g,'-').slice(0,32);
    const url=sameOriginPath(body.url||'/');
    const ttl=Math.max(60,Math.min(86400,Number(body.ttlSeconds)||21600));
    const sql='INSERT INTO notification_events(event_key,kind,source,scheduled_at,title,body,url,tag,urgency,ttl_seconds,status,created_at) '+
      "VALUES(?,?,'manual',?,?,?,?,?,?,?,'pending',?) ON CONFLICT(event_key) DO NOTHING";
    await env.DB.prepare(sql).bind(
      eventKey,'manual',new Date(Date.parse(scheduledAt)).toISOString(),title,message,url,tag,
      body.urgency==='high'?'high':'normal',ttl,now
    ).run();
    return json({ok:true,eventKey},200,headers);
  }catch(error){
    const reason=String(error?.message||error);
    const known=/^(idempotencyKey|title|body)-(required|too-long)$|^invalid-url$/.test(reason);
    return json({error:known?reason:'invalid-request'},400,headers);
  }
}

async function ensureDeliveries(env,eventKey){
  const now=new Date().toISOString();
  await env.DB.prepare(
    "INSERT OR IGNORE INTO deliveries(event_key,subscription_id,status,attempts,updated_at) "+
    "SELECT ?,id,'pending',0,? FROM subscriptions WHERE enabled=1"
  ).bind(eventKey,now).run();
}

async function pushOne(env,event,delivery){
  const sub=await env.DB.prepare('SELECT * FROM subscriptions WHERE id=? AND enabled=1')
    .bind(delivery.subscription_id).first();
  if(!sub)return;

  const payload={
    title:event.title,
    body:event.body,
    url:event.url,
    tag:event.tag,
    eventKey:event.event_key,
    songId:event.song_id||null,
    icon:'/icon-192.png?v=9',
    badge:'/favicon-32.png?v=8',
    timestamp:Date.parse(event.scheduled_at)
  };
  const subscription={endpoint:sub.endpoint,expirationTime:null,keys:{p256dh:sub.p256dh,auth:sub.auth}};
  const vapid={subject:env.VAPID_SUBJECT,publicKey:env.VAPID_PUBLIC_KEY,privateKey:env.VAPID_PRIVATE_KEY};

  try{
    const pushRequest=await buildPushPayload(
      {data:JSON.stringify(payload),options:{ttl:event.ttl_seconds,urgency:event.urgency,topic:event.tag.slice(0,32)}},
      subscription,
      vapid
    );
    const response=await fetch(sub.endpoint,pushRequest);
    const now=new Date().toISOString();

    if(response.ok){
      await env.DB.batch([
        env.DB.prepare("UPDATE deliveries SET status='sent',attempts=attempts+1,response_code=?,updated_at=?,last_error=NULL WHERE event_key=? AND subscription_id=?")
          .bind(response.status,now,event.event_key,sub.id),
        env.DB.prepare('UPDATE subscriptions SET last_success_at=?,failure_count=0,updated_at=? WHERE id=?')
          .bind(now,now,sub.id)
      ]);
      return;
    }

    if(response.status===404||response.status===410){
      await env.DB.batch([
        env.DB.prepare("UPDATE deliveries SET status='gone',attempts=attempts+1,response_code=?,updated_at=? WHERE event_key=? AND subscription_id=?")
          .bind(response.status,now,event.event_key,sub.id),
        env.DB.prepare('UPDATE subscriptions SET enabled=0,failure_count=failure_count+1,updated_at=? WHERE id=?')
          .bind(now,sub.id)
      ]);
      return;
    }

    const retry=delivery.attempts+1<MAX_ATTEMPTS?'retry':'failed';
    await env.DB.prepare('UPDATE deliveries SET status=?,attempts=attempts+1,response_code=?,updated_at=?,last_error=? WHERE event_key=? AND subscription_id=?')
      .bind(retry,response.status,now,'push-http-'+response.status,event.event_key,sub.id).run();
  }catch(error){
    const now=new Date().toISOString();
    const retry=delivery.attempts+1<MAX_ATTEMPTS?'retry':'failed';
    await env.DB.prepare('UPDATE deliveries SET status=?,attempts=attempts+1,updated_at=?,last_error=? WHERE event_key=? AND subscription_id=?')
      .bind(retry,now,String(error?.message||error).slice(0,500),event.event_key,sub.id).run();
  }
}

async function dispatchDue(env){
  const now=new Date().toISOString();
  const due=(await env.DB.prepare(
    "SELECT * FROM notification_events WHERE status IN ('pending','sending') AND scheduled_at<=? ORDER BY scheduled_at ASC LIMIT 4"
  ).bind(now).all()).results||[];

  let deliveriesProcessed=0;
  for(const event of due){
    await ensureDeliveries(env,event.event_key);
    await env.DB.prepare("UPDATE notification_events SET status='sending' WHERE event_key=? AND status='pending'")
      .bind(event.event_key).run();

    const pending=(await env.DB.prepare(
      "SELECT * FROM deliveries WHERE event_key=? AND status IN ('pending','retry') AND attempts<? ORDER BY attempts ASC,updated_at ASC LIMIT ?"
    ).bind(event.event_key,MAX_ATTEMPTS,Math.max(0,MAX_DELIVERIES_PER_RUN-deliveriesProcessed)).all()).results||[];

    for(const delivery of pending){
      if(deliveriesProcessed>=MAX_DELIVERIES_PER_RUN)break;
      await pushOne(env,event,delivery);
      deliveriesProcessed++;
    }

    const remaining=await env.DB.prepare(
      "SELECT COUNT(*) AS n FROM deliveries WHERE event_key=? AND status IN ('pending','retry') AND attempts<?"
    ).bind(event.event_key,MAX_ATTEMPTS).first();

    if(Number(remaining?.n||0)===0){
      await env.DB.prepare("UPDATE notification_events SET status='sent',sent_at=? WHERE event_key=?")
        .bind(new Date().toISOString(),event.event_key).run();
    }
    if(deliveriesProcessed>=MAX_DELIVERIES_PER_RUN)break;
  }
  return {events:due.length,deliveriesProcessed};
}

async function adminHealth(request,env){
  const origin=request.headers.get('origin')||'';
  const headers=cors(origin,env);
  if(origin&&origin!==env.SITE_ORIGIN)return json({error:'origin-not-allowed'},403,headers);
  if(!authorized(request,env))return json({error:'unauthorized'},401,headers);
  const subscriptions=await env.DB.prepare('SELECT COUNT(*) AS n FROM subscriptions WHERE enabled=1').first();
  const pending=await env.DB.prepare("SELECT COUNT(*) AS n FROM notification_events WHERE status IN ('pending','sending')").first();
  const sent=await env.DB.prepare("SELECT COUNT(*) AS n FROM notification_events WHERE status='sent'").first();
  return json({
    ok:true,
    subscriptions:Number(subscriptions?.n||0),
    pending:Number(pending?.n||0),
    sent:Number(sent?.n||0)
  },200,headers);
}

export default {
  async fetch(request,env){
    const url=new URL(request.url);
    const origin=request.headers.get('origin')||'';
    if(request.method==='OPTIONS')return new Response(null,{status:204,headers:cors(origin,env)});
    if(url.pathname==='/v1/config'&&request.method==='GET'){
      return json({enabled:true,vapidPublicKey:env.VAPID_PUBLIC_KEY,timezone:'America/New_York'},200,cors(origin,env));
    }
    if(url.pathname==='/v1/subscriptions'&&request.method==='POST')return upsertSubscription(request,env);
    if(url.pathname==='/v1/subscriptions'&&request.method==='DELETE')return deleteSubscription(request,env);
    if(url.pathname==='/v1/admin/catalog/sync'&&request.method==='POST')return syncCatalog(request,env);
    if(url.pathname==='/v1/admin/send'&&request.method==='POST')return manualSend(request,env);
    if(url.pathname==='/v1/admin/health'&&request.method==='GET')return adminHealth(request,env);
    if(url.pathname==='/health')return json({ok:true,service:'ipcdj-worship-push'});
    return json({error:'not-found'},404);
  },
  async scheduled(_controller,env,ctx){
    ctx.waitUntil(dispatchDue(env));
  }
};
