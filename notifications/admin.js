(()=>{
  'use strict';
  const CONFIG_URL='./config.json';
  const $=id=>document.getElementById(id);
  const tokenInput=$('token');
  const health=$('health');
  const status=$('status');
  const send=$('send');
  const when=$('when');
  const scheduleWrap=$('schedule-wrap');

  let apiOrigin='';
  let token=sessionStorage.getItem('ipcdj-push-admin-token')||'';
  tokenInput.value=token;

  const message=(el,text,type='')=>{
    el.textContent=text;
    el.className='status'+(type?' '+type:'');
  };

  async function loadApi(){
    const response=await fetch(CONFIG_URL,{cache:'no-store'});
    if(!response.ok)throw new Error('No se pudo cargar la configuración.');
    const config=await response.json();
    apiOrigin=String(config.apiOrigin||'').replace(/\/$/,'');
    if(!apiOrigin)throw new Error('API de notificaciones no configurada.');
  }

  async function checkHealth(){
    if(!token||!apiOrigin){message(health,'Ingresa el token para ver el estado.');return;}
    try{
      const response=await fetch(apiOrigin+'/v1/admin/health',{
        headers:{Authorization:'Bearer '+token},cache:'no-store'
      });
      if(response.status===401)throw new Error('Token incorrecto.');
      if(!response.ok)throw new Error('Backend no disponible ('+response.status+').');
      const data=await response.json();
      message(health,'Activos: '+data.subscriptions+' · Pendientes: '+data.pending+' · Enviados: '+data.sent,'ok');
    }catch(error){
      message(health,String(error?.message||error),'error');
    }
  }

  $('save-token').addEventListener('click',()=>{
    token=tokenInput.value.trim();
    if(token)sessionStorage.setItem('ipcdj-push-admin-token',token);
    else sessionStorage.removeItem('ipcdj-push-admin-token');
    checkHealth();
  });

  when.addEventListener('change',()=>{
    scheduleWrap.hidden=when.value!=='scheduled';
  });

  send.addEventListener('click',async()=>{
    status.textContent='';
    if(!token){message(status,'Primero ingresa el token administrativo.','error');return;}
    const title=$('title').value.trim();
    const body=$('body').value.trim();
    if(!title||!body){message(status,'Falta el título o el mensaje.','error');return;}

    let scheduledAt;
    if(when.value==='scheduled'){
      const value=$('scheduled').value;
      const epoch=Date.parse(value);
      if(!Number.isFinite(epoch)){message(status,'Selecciona una fecha y hora válida.','error');return;}
      scheduledAt=new Date(epoch).toISOString();
    }

    const idempotencyKey=(crypto.randomUUID?crypto.randomUUID():Date.now().toString(36));
    send.disabled=true;
    try{
      const response=await fetch(apiOrigin+'/v1/admin/send',{
        method:'POST',
        headers:{'Content-Type':'application/json',Authorization:'Bearer '+token},
        body:JSON.stringify({
          idempotencyKey,
          title,
          body,
          scheduledAt,
          urgency:$('urgency').value,
          url:$('url').value.trim()||'/'
        })
      });
      const data=await response.json().catch(()=>({}));
      if(response.status===401)throw new Error('Token incorrecto.');
      if(!response.ok)throw new Error(data.error||('Error '+response.status));
      message(status,when.value==='scheduled'?'Notificación programada.':'Notificación en cola para enviar.','ok');
      await checkHealth();
    }catch(error){
      message(status,String(error?.message||error),'error');
    }finally{
      send.disabled=false;
    }
  });

  loadApi().then(checkHealth).catch(error=>message(health,String(error?.message||error),'error'));
})();