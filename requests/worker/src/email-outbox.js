// IPCDJ request email outbox. No browser access or direct public endpoint.
// The Email Service binding is restricted to the church's verified recipient.
// Sending stays OFF until Cloudflare's sender domain + binding are verified.
export const NOTIFY_TO="ipcdjofficial@gmail.com";
export const MAX_EMAIL_ATTEMPTS=8;
const BATCH_SIZE=8;
const LEASE_MS=5*60*1000;
const permanentErrors=new Set([
  "E_RECIPIENT_SUPPRESSED","E_TOO_MANY_RECIPIENTS","E_CONTENT_TOO_LARGE",
  "E_VALIDATION_ERROR","E_FIELD_MISSING"
]);
const allowedSender=value=>typeof value==="string"&&
  /^[a-z0-9._%+-]+@(?:[a-z0-9-]+\.)*ipcdj\.org$/i.test(value)&&value.length<150;
const nowDate=()=>new Date();
const addMs=(now,ms)=>new Date(now.getTime()+ms).toISOString();
const changed=result=>Number(result?.meta?.changes??result?.changes??0)===1;
const normalizeError=error=>{
  const code=String(error?.code||"");
  return /^E_[A-Z0-9_]{3,60}$/.test(code)?code:"EMAIL_SEND_ERROR";
};
const safeText=value=>String(value??"").replace(/[\u0000-\u001f\u007f]/g," ").slice(0,180);
export function emailConfigured(env){
  return env?.APP_ENV==="staging"&&env?.EMAIL_NOTIFICATIONS_ENABLED==="true"&&
    !!env.DB&&typeof env.EMAIL?.send==="function"&&
    String(env.EMAIL_TO||"")===NOTIFY_TO&&allowedSender(env.EMAIL_FROM);
}
function retryDelay(attempts){
  return Math.min(6*60*60*1000,Math.pow(2,Math.min(attempts,8))*60*1000);
}
export async function processEmailOutbox(env,{clock=nowDate}={}){
  const stats={configured:emailConfigured(env),claimed:0,accepted:0,retried:0,failed:0};
  if(!stats.configured)return stats;
  const now=clock();
  const nowIso=now.toISOString();
  // A Worker terminated after its final attempt must not strand the event
  // indefinitely in 'sending'; record it as failed when the lease expires.
  const exhausted=await env.DB.prepare(
    "UPDATE request_outbox SET status='failed',last_error='EMAIL_ATTEMPTS_EXHAUSTED' "+
    "WHERE status='sending' AND attempts>=? AND next_attempt_at<=?"
  ).bind(MAX_EMAIL_ATTEMPTS,nowIso).run();
  stats.failed+=Number(exhausted?.meta?.changes??exhausted?.changes??0);
  // Recover stale 'sending' leases; only one invocation can claim a given
  // attempt because UPDATE checks status, due-time and the old attempt number.
  const candidates=(await env.DB.prepare(
    "SELECT o.id,o.request_id,o.attempts,o.event_type,r.title,r.artist "+
    "FROM request_outbox o JOIN song_requests r ON r.id=o.request_id "+
    "WHERE o.event_type='new_submission' AND o.status IN('pending','retry','sending') AND o.next_attempt_at<=? "+
    "AND o.attempts<? ORDER BY o.next_attempt_at ASC,o.id ASC LIMIT ?"
  ).bind(nowIso,MAX_EMAIL_ATTEMPTS,BATCH_SIZE).all()).results||[];
  for(const item of candidates){
    const leaseExpiry=addMs(now,LEASE_MS);
    const claim=await env.DB.prepare(
      "UPDATE request_outbox SET status='sending',attempts=attempts+1,next_attempt_at=? "+
      "WHERE id=? AND attempts=? AND status IN('pending','retry','sending') AND next_attempt_at<=?"
    ).bind(leaseExpiry,item.id,item.attempts,nowIso).run();
    if(!changed(claim))continue;
    const attempt=item.attempts+1;
    stats.claimed++;
    try{
      const title=safeText(item.title),artist=safeText(item.artist);
      const reply=await env.EMAIL.send({
        to:NOTIFY_TO,
        from:{email:env.EMAIL_FROM,name:"IPCDJ Worship"},
        subject:"[IPCDJ Staging] Nueva solicitud de canción",
        text:["Nueva solicitud recibida en IPCDJ Worship (Staging).",
          "Canción: "+title,"Artista: "+artist,
          "Solicitud: "+item.request_id,
          "Esta solicitud está pendiente de revisión.",
          "No se ha programado automáticamente para ningún culto."
        ].join("\n")
      });
      if(!reply||typeof reply.messageId!=="string"||!reply.messageId){
        const e=new Error("Email Service acknowledgement missing");e.code="E_NO_ACK";throw e;
      }
      const ack=await env.DB.prepare(
        "UPDATE request_outbox SET status='sent',sent_at=?,last_error=NULL "+
        "WHERE id=? AND status='sending' AND attempts=?"
      ).bind(clock().toISOString(),item.id,attempt).run();
      if(changed(ack))stats.accepted++;
      // A send accepted by Email Service is NOT proof of delivery to Gmail.
    }catch(err){
      const code=normalizeError(err);
      const terminal=attempt>=MAX_EMAIL_ATTEMPTS||permanentErrors.has(code);
      const next=terminal?"failed":"retry";
      const retryAt=addMs(clock(),retryDelay(attempt));
      const updated=await env.DB.prepare(
        "UPDATE request_outbox SET status=?,next_attempt_at=?,last_error=? "+
        "WHERE id=? AND status='sending' AND attempts=?"
      ).bind(next,retryAt,code,item.id,attempt).run();
      if(changed(updated)){if(terminal)stats.failed++;else stats.retried++;}
    }
  }
  return stats;
}