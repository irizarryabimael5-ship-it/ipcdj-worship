(()=>{
  'use strict';

  const CONFIG_URL='./notifications/config.json';
  let configPromise=null;
  let remoteConfigPromise=null;

  const isIos=()=>/iPhone|iPad|iPod/i.test(navigator.userAgent||'')||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  const isStandalone=()=>navigator.standalone===true||(window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||(window.matchMedia&&window.matchMedia('(display-mode: fullscreen)').matches);

  const decodeKey=value=>{
    const padding='='.repeat((4-value.length%4)%4);
    const base64=(value+padding).replace(/-/g,'+').replace(/_/g,'/');
    const raw=atob(base64);
    return Uint8Array.from([...raw].map(ch=>ch.charCodeAt(0)));
  };

  async function loadConfig(force=false){
    if(!configPromise||force){
      configPromise=fetch(CONFIG_URL,{cache:'no-store'}).then(async response=>{
        if(!response.ok)throw new Error('notification-config-unavailable');
        return Object.freeze(await response.json());
      });
    }
    return configPromise;
  }

  async function loadRemoteConfig(config,force=false){
    if(!config?.enabled||!config?.apiOrigin)return Object.freeze({enabled:false});
    if(!remoteConfigPromise||force){
      remoteConfigPromise=fetch(config.apiOrigin.replace(/\/$/,'')+'/v1/config',{
        cache:'no-store',credentials:'omit'
      }).then(async response=>{
        if(!response.ok)throw new Error('notification-backend-unavailable-'+response.status);
        return Object.freeze(await response.json());
      });
    }
    return remoteConfigPromise;
  }

  async function resolvedConfig(force=false){
    const local=await loadConfig(force);
    if(!local.enabled||!local.apiOrigin)return Object.freeze({...local,remoteEnabled:false,vapidPublicKey:''});
    const remote=await loadRemoteConfig(local,force);
    return Object.freeze({
      ...local,
      remoteEnabled:remote.enabled===true,
      vapidPublicKey:String(remote.vapidPublicKey||''),
      timezone:String(remote.timezone||local.timezone||'America/New_York')
    });
  }

  async function capabilities(){
    const config=await resolvedConfig().catch(()=>({enabled:false,remoteEnabled:false,vapidPublicKey:''}));
    const supported=('serviceWorker' in navigator)&&('PushManager' in window)&&('Notification' in window);
    return Object.freeze({
      supported,
      configured:!!(config.enabled&&config.remoteEnabled&&config.apiOrigin&&config.vapidPublicKey),
      enabled:!!(config.enabled&&config.remoteEnabled),
      backendReachable:!!config.remoteEnabled,
      permission:('Notification' in window)?Notification.permission:'unsupported',
      ios:isIos(),
      standalone:isStandalone(),
      requiresHomeScreen:isIos()&&!isStandalone(),
    });
  }

  async function postSubscription(config,subscription){
    const response=await fetch(config.apiOrigin.replace(/\/$/,'')+'/v1/subscriptions',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      credentials:'omit',
      body:JSON.stringify({
        subscription:subscription.toJSON(),
        siteOrigin:location.origin,
        userAgent:navigator.userAgent||'',
        language:navigator.language||'es',
        standalone:isStandalone(),
      })
    });
    if(!response.ok)throw new Error('subscription-sync-failed-'+response.status);
    return response.json().catch(()=>({ok:true}));
  }

  async function enable(){
    const config=await resolvedConfig(true);
    const state=await capabilities();
    if(!state.supported)throw new Error('push-unsupported');
    if(!state.configured)throw new Error('push-not-configured');
    if(state.requiresHomeScreen)throw new Error('ios-home-screen-required');
    if(Notification.permission==='denied')throw new Error('notification-permission-denied');

    const permission=Notification.permission==='granted'
      ? 'granted'
      : await Notification.requestPermission();
    if(permission!=='granted')throw new Error('notification-permission-'+permission);

    const registration=await navigator.serviceWorker.ready;
    let subscription=await registration.pushManager.getSubscription();
    if(!subscription){
      subscription=await registration.pushManager.subscribe({
        userVisibleOnly:true,
        applicationServerKey:decodeKey(config.vapidPublicKey)
      });
    }
    await postSubscription(config,subscription);
    return Object.freeze({ok:true,permission:'granted',subscribed:true});
  }

  async function disable(){
    const config=await resolvedConfig().catch(()=>null);
    const registration=await navigator.serviceWorker.ready;
    const subscription=await registration.pushManager.getSubscription();
    if(subscription&&config?.apiOrigin){
      await fetch(config.apiOrigin.replace(/\/$/,'')+'/v1/subscriptions',{
        method:'DELETE',
        headers:{'Content-Type':'application/json'},
        credentials:'omit',
        body:JSON.stringify({endpoint:subscription.endpoint,siteOrigin:location.origin})
      }).catch(()=>{});
    }
    if(subscription)await subscription.unsubscribe().catch(()=>false);
    return Object.freeze({ok:true,subscribed:false});
  }

  async function reconcileExisting(){
    if(!('serviceWorker' in navigator)||!('PushManager' in window)||!('Notification' in window))return false;
    if(Notification.permission!=='granted')return false;
    const config=await resolvedConfig().catch(()=>null);
    if(!config?.enabled||!config?.remoteEnabled||!config.apiOrigin||!config.vapidPublicKey)return false;
    const registration=await navigator.serviceWorker.ready;
    const subscription=await registration.pushManager.getSubscription();
    if(!subscription)return false;
    await postSubscription(config,subscription).catch(()=>{});
    return true;
  }

  async function getState(){
    const state=await capabilities();
    let subscribed=false;
    if(state.supported&&state.permission==='granted'){
      const registration=await navigator.serviceWorker.ready;
      subscribed=!!(await registration.pushManager.getSubscription());
    }
    return Object.freeze({...state,subscribed});
  }

  window.IPCDJ_NOTIFICATIONS=Object.freeze({
    capabilities,
    getState,
    enable,
    disable,
    reconcileExisting,
    reloadConfig:()=>resolvedConfig(true),
  });

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',()=>{reconcileExisting().catch(()=>{})},{once:true});
  }else{
    reconcileExisting().catch(()=>{});
  }
})();
