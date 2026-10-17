/* IPCDJ Worship — isolated Staging song-request frontend (never production). */
(()=>{"use strict";
  const API="https://ipcdj-song-requests-staging.ipcdjofficial.workers.dev";
  // PUBLIC Turnstile widget sitekey; the private TURNSTILE_SECRET is Worker-only.
  const SITEKEY="0x4AAAAAAFYyhqnTm_7Glvdk";
  const allowedHosts=new Set(["staging.worship.ipcdj.org","ipcdj-worship-staging.pages.dev"]);
  if(!allowedHosts.has(location.hostname))return;
  const byId=id=>document.getElementById(id);
  let lastPoll=0,feedBusy=false,healthBusy=false,intakeReady=false;
  let widgetId=null,turnstileLoading=null,pendingIdempotency=null;
  const timeoutFetch=async(path,options={},ms=8500)=>{
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),ms);
    try{return await fetch(API+path,{mode:"cors",cache:"no-store",...options,signal:controller.signal});}
    finally{clearTimeout(timer);}
  };
  const message=(value,state="idle")=>{
    const el=byId("requests-form-status");
    if(el){el.textContent=value;el.dataset.state=state;}
  };
  function markReady(ready){
    intakeReady=ready;
    const button=byId("requests-submit");
    if(button){button.disabled=!ready;button.setAttribute("aria-disabled",String(!ready));}
  }
  async function feed(){
    if(feedBusy||Date.now()-lastPoll<45000)return;
    feedBusy=true;lastPoll=Date.now();
    try{
      const response=await timeoutFetch("/v1/requests",{},8000);
      if(!response.ok)throw new Error("public feed status");
      const body=await response.json();
      if(body?.ok!==true||!Array.isArray(body.songs))throw new Error("invalid public feed");
      window.dispatchEvent(new CustomEvent("ipcdj:requests-published-feed",{
        detail:{songs:body.songs.slice(0,100)}
      }));
      const status=byId("requested-feed-status");
      if(status)status.textContent="Canciones solicitadas · lista actualizada.";
    }catch(_){
      const status=byId("requested-feed-status");
      if(status)status.textContent="Mostrando las solicitudes disponibles. Sin conexión a la lista en este momento.";
    }finally{feedBusy=false;}
  }
  function installTurnstile(){
    if(widgetId!==null)return Promise.resolve();
    if(turnstileLoading)return turnstileLoading;
    turnstileLoading=new Promise((resolve,reject)=>{
      const attach=()=>{
        try{
          if(!window.turnstile||!byId("requests-turnstile"))throw new Error("verification missing");
          widgetId=window.turnstile.render("#requests-turnstile",{
            sitekey:SITEKEY,action:"song_request",theme:"dark"
          });
          resolve();
        }catch(error){reject(error);}
      };
      if(window.turnstile){attach();return;}
      const script=document.createElement("script");
      script.async=true;
      script.src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.onload=attach;
      script.onerror=()=>reject(new Error("verification script missing"));
      document.head.appendChild(script);
    }).catch(error=>{turnstileLoading=null;throw error;});
    return turnstileLoading;
  }
  async function health(){
    if(healthBusy)return;
    healthBusy=true;
    try{
      const response=await timeoutFetch("/health",{},6500);
      if(!response.ok)throw new Error("health status");
      const data=await response.json();
      // Fail closed unless ALL required backend systems are active.
      const ready=data?.ok===true&&data.environment==="staging"&&
        data.storageConfigured===true&&data.intakeEnabled===true&&
        data.notificationsEnabled===true&&data.publicationEnabled===true;
      if(!ready){
        markReady(false);
        message("Estamos preparando las solicitudes. Pronto podrás enviar una canción.");
        return;
      }
      await installTurnstile();
      markReady(true);
      message("Completa el formulario y la verificación para enviar tu sugerencia.");
    }catch(_){
      markReady(false);
      message("Las solicitudes aún no están disponibles. Intenta nuevamente más tarde.");
    }finally{healthBusy=false;}
  }
  async function submit(event){
    event.preventDefault();
    const form=event.currentTarget;
    if(!intakeReady)return;
    const fields=new FormData(form);
    const title=String(fields.get("title")||"").trim();
    const artist=String(fields.get("artist")||"").trim();
    const link=String(fields.get("link")||"").trim();
    const comment=String(fields.get("comment")||"").trim();
    if(!title||!artist||title.length>120||artist.length>120||link.length>500||comment.length>350){
      message("Escribe el nombre y artista de la canción.", "error");return;
    }
    let turnstileToken="";
    try{turnstileToken=window.turnstile?.getResponse(widgetId)||"";}catch(_){}
    if(!turnstileToken){message("Completa la verificación de seguridad.", "error");return;}
    const button=byId("requests-submit");
    if(!button||button.disabled)return;
    pendingIdempotency ||= crypto.randomUUID();
    button.disabled=true;
    message("Enviando la solicitud…");
    try{
      const response=await timeoutFetch("/v1/requests",{
        method:"POST",headers:{"Content-Type":"application/json"},
        body:JSON.stringify({title,artist,link,comment,turnstileToken,
          idempotencyKey:pendingIdempotency})
      },12000);
      const answer=await response.json().catch(()=>({}));
      if(!response.ok||answer.ok!==true)throw new Error("not confirmed");
      pendingIdempotency=null;
      form.reset();
      message("Solicitud recibida. Será revisada antes de aparecer en la lista.", "success");
    }catch(_){
      message("No pudimos confirmar la solicitud. Vuelve a intentarlo.", "error");
    }finally{
      try{window.turnstile?.reset(widgetId);}catch(_){}
      button.disabled=!intakeReady;
    }
  }
  function init(){
    const form=byId("song-request-form");
    if(!form)return;
    form.addEventListener("input",()=>{pendingIdempotency=null;});
    form.addEventListener("submit",submit);
    markReady(false);
    window.addEventListener("ipcdj:requests-visible",()=>{
      void feed();
      void health();
    });
    if(!byId("panel-solicitudes")?.hidden){
      void feed();void health();
    }
  }
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init,{once:true});
  else init();
})();
