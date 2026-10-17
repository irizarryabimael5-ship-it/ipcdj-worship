// Controlled one-shot outbound email acceptance probe; never exposed by HTTP.
export const PROBE_ID="ipcdj-email-probe-20261017-01";
export const PROBE_FROM="solicitudes@ipcdj.org";
export const PROBE_TO="ipcdjofficial@gmail.com";
const safeError=error=>{
  const value=String(error?.code||"");
  return /^E_[A-Z0-9_]{3,60}$/.test(value)?value:"EMAIL_SEND_ERROR";
};
const changed=result=>Number(result?.meta?.changes??result?.changes??0)===1;
export function probeAllowed(env){
  return env?.APP_ENV==="staging" &&
    env?.INGEST_ENABLED==="false" &&
    env?.EMAIL_NOTIFICATIONS_ENABLED==="false" &&
    env?.MAIL_PROBE_ENABLED==="true" &&
    env?.MAIL_PROBE_ID===PROBE_ID &&
    env?.EMAIL_FROM===PROBE_FROM &&
    env?.EMAIL_TO===PROBE_TO &&
    typeof env?.DB?.prepare==="function" &&
    typeof env?.EMAIL?.send==="function";
}
export async function runOneTimeEmailProbe(env){
  if(!probeAllowed(env))return {enabled:false,attempted:false};
  const start=new Date().toISOString();
  // The UNIQUE id is the at-most-once gate. Claim is committed *before* calling
  // Email Service. Interrupted sends remain claimed; the probe never retries.
  const claim=await env.DB.prepare(
    "INSERT OR IGNORE INTO email_probe_results(id,status,started_at) VALUES(?,'attempting',?)"
  ).bind(PROBE_ID,start).run();
  if(!changed(claim))return {enabled:true,attempted:false,alreadyClaimed:true};
  try{
    const response=await env.EMAIL.send({
      from:PROBE_FROM,
      to:PROBE_TO,
      subject:"[IPCDJ Staging] Prueba única de notificaciones",
      text:[
        "IPCDJ Worship — PRUEBA CONTROLADA (Staging).",
        "Este correo comprueba la entrega del servicio de notificaciones.",
        "No corresponde a una solicitud real de canción.",
        "El formulario público y los avisos automáticos siguen desactivados.",
        "Identificador: "+PROBE_ID
      ].join("\n")
    });
    if(typeof response?.messageId!=="string"||!response.messageId){
      const error=new Error("Missing provider acknowledgement");
      error.code="E_NO_ACK";throw error;
    }
    await env.DB.prepare(
      "UPDATE email_probe_results SET status='accepted',message_id=?,completed_at=? WHERE id=? AND status='attempting'"
    ).bind(response.messageId,new Date().toISOString(),PROBE_ID).run();
    return {enabled:true,attempted:true,accepted:true};
  }catch(error){
    const code=safeError(error);
    await env.DB.prepare(
      "UPDATE email_probe_results SET status='failed',error_code=?,completed_at=? WHERE id=? AND status='attempting'"
    ).bind(code,new Date().toISOString(),PROBE_ID).run();
    return {enabled:true,attempted:true,accepted:false,errorCode:code};
  }
}
