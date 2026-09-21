(()=>{
  'use strict';

  const STYLE_ID='ipcdj-notification-ui-style';
  const CARD_ID='ipcdj-notification-card';

  function addStyles(){
    if(document.getElementById(STYLE_ID))return;
    const style=document.createElement('style');
    style.id=STYLE_ID;
    style.textContent=`
      #${CARD_ID}[hidden]{display:none!important}
      .notification-card{padding:16px 18px}
      .notification-row{display:flex;align-items:center;justify-content:space-between;gap:14px;min-width:0}
      .notification-copy{min-width:0}
      .notification-copy .section-title{margin:0 0 4px}
      .notification-copy .section-note{margin:0;max-width:560px}
      .notification-action{
        appearance:none;-webkit-appearance:none;flex:0 0 auto;min-height:42px;
        padding:9px 14px;border:1px solid rgba(255,255,255,.16);border-radius:12px;
        background:rgba(255,255,255,.07);color:#fff;font:inherit;font-size:.84rem;
        font-weight:780;cursor:pointer;touch-action:manipulation;
      }
      .notification-action:hover{background:rgba(255,255,255,.11)}
      .notification-action:focus-visible{outline:2px solid rgba(143,176,255,.9);outline-offset:2px}
      .notification-action[disabled]{opacity:.55;cursor:default}
      .notification-status{margin-top:8px;color:#9fb0c6;font-size:.78rem;line-height:1.4}
      @media(max-width:640px){
        .notification-row{align-items:flex-start;flex-direction:column}
        .notification-action{width:100%}
      }
      @media(prefers-reduced-motion:reduce){.notification-action{transition:none!important}}
      @media(forced-colors:active){.notification-action{border:1px solid ButtonText}}
    `;
    document.head.appendChild(style);
  }

  function makeCard(){
    let card=document.getElementById(CARD_ID);
    if(card)return card;
    const footer=document.querySelector('#panel-inicio footer');
    if(!footer)return null;
    card=document.createElement('section');
    card.id=CARD_ID;
    card.className='card notification-card';
    card.hidden=true;
    card.innerHTML=`
      <div class="notification-row">
        <div class="notification-copy">
          <h2 class="section-title">Notificaciones</h2>
          <p class="section-note" data-notification-description>Mantente al día con las canciones en preparación.</p>
          <div class="notification-status" data-notification-status aria-live="polite"></div>
        </div>
        <button class="notification-action" type="button" data-notification-action>Activar</button>
      </div>
    `;
    footer.before(card);
    return card;
  }

  async function localFeatureEnabled(){
    try{
      const response=await fetch('./notifications/config.json',{cache:'no-store'});
      if(!response.ok)return false;
      const config=await response.json();
      return config?.enabled===true;
    }catch(_){
      return false;
    }
  }

  function copyFor(state){
    if(state.ios&&state.requiresHomeScreen){
      return {
        description:'Añade IPCDJ Worship a tu pantalla de inicio para recibir notificaciones en iPhone o iPad.',
        status:'Después abre la app desde tu pantalla de inicio y actívalas aquí.',
        action:'Cómo activarlas',
        mode:'ios-install'
      };
    }
    if(!state.supported){
      return {
        description:'Este navegador no ofrece Web Push para IPCDJ Worship.',
        status:'Puedes seguir usando el sitio normalmente.',
        action:'No disponible',
        mode:'unsupported'
      };
    }
    if(state.permission==='denied'){
      return {
        description:'Las notificaciones están bloqueadas en este navegador.',
        status:'Cambia el permiso de notificaciones del sitio en la configuración del navegador para volver a activarlas.',
        action:'Bloqueadas',
        mode:'denied'
      };
    }
    if(state.subscribed){
      return {
        description:'Recordatorios breves para las canciones que estén en preparación y sus estrenos.',
        status:'Notificaciones activadas en este dispositivo.',
        action:'Desactivar',
        mode:'disable'
      };
    }
    return {
      description:'Recordatorios breves para las canciones que estén en preparación y sus estrenos.',
      status:'Solo recibirás avisos relevantes. No pediremos permiso hasta que pulses Activar.',
      action:'Activar',
      mode:'enable'
    };
  }

  async function refresh(card){
    const api=window.IPCDJ_NOTIFICATIONS;
    if(!api)return;
    const state=await api.getState().catch(()=>null);
    if(!state||!state.enabled||!state.configured){
      card.hidden=true;
      return;
    }

    card.hidden=false;
    const text=copyFor(state);
    const description=card.querySelector('[data-notification-description]');
    const status=card.querySelector('[data-notification-status]');
    const button=card.querySelector('[data-notification-action]');
    description.textContent=text.description;
    status.textContent=text.status;
    button.textContent=text.action;
    button.dataset.mode=text.mode;
    button.disabled=text.mode==='unsupported'||text.mode==='denied';
  }

  async function activate(card,button){
    const api=window.IPCDJ_NOTIFICATIONS;
    const mode=button.dataset.mode;
    if(mode==='ios-install'){
      const status=card.querySelector('[data-notification-status]');
      status.textContent='En Safari: Compartir → Añadir a pantalla de inicio. Luego abre IPCDJ Worship desde el icono y toca Activar.';
      return;
    }
    button.disabled=true;
    try{
      if(mode==='disable')await api.disable();
      else if(mode==='enable')await api.enable();
    }catch(error){
      const status=card.querySelector('[data-notification-status]');
      const reason=String(error?.message||error);
      status.textContent=reason.includes('denied')
        ? 'El navegador bloqueó el permiso. Puedes cambiarlo desde la configuración del sitio.'
        : 'No se pudo completar ahora. Intenta de nuevo.';
    }finally{
      await refresh(card);
    }
  }

  async function mount(){
    if(!(await localFeatureEnabled()))return;
    addStyles();
    const card=makeCard();
    if(!card)return;
    const button=card.querySelector('[data-notification-action]');
    button.addEventListener('click',()=>activate(card,button));
    await refresh(card);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>mount().catch(()=>{}),{once:true});
  else mount().catch(()=>{});
})();