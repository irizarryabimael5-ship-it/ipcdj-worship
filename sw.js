importScripts("./notifications/sw-foundation.js");

const CACHE_NAME = "ipcdj-worship-v165";
const OFFLINE_PAGE = "./__offline_index__";
const STATIC_ASSETS = [
  "./favicon.svg",
  "./favicon-32.png",
  "./favicon.ico",
  "./apple-touch-icon.png",
  "./app-icon-safe.svg",
  "./icon-192.png",
  "./icon-512.png",
  "./spotify.svg",
  "./apple-music.svg",
  "./youtube-music.svg",
  "./launch-logo-white.svg",
  "./ios-launch/apple-launch-1320x2868.png",
  "./ios-launch/apple-launch-1260x2736.png",
  "./ios-launch/apple-launch-1206x2622.png",
  "./ios-launch/apple-launch-1290x2796.png",
  "./ios-launch/apple-launch-1179x2556.png",
  "./ios-launch/apple-launch-1284x2778.png",
  "./ios-launch/apple-launch-1170x2532.png",
  "./ios-launch/apple-launch-1125x2436.png",
  "./ios-launch/apple-launch-1242x2688.png",
  "./ios-launch/apple-launch-828x1792.png",
  "./ios-launch/apple-launch-1242x2208.png",
  "./ios-launch/apple-launch-750x1334.png",
  "./ios-launch/apple-launch-640x1136.png",
  "./manifest-v9.webmanifest",
  "./notifications/sw-foundation.js",
  "./notifications/client.js",
  "./notifications/ui.js",
  "./notifications/config.json"
];

self.addEventListener("install",event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE_NAME);

    await Promise.allSettled(
      STATIC_ASSETS.map(async asset=>{
        try{
          const response=await fetch(asset,{cache:"reload"});
          if(response&&response.ok)await cache.put(asset,response.clone());
        }catch(_){}
      })
    );

    try{
      const controller=new AbortController();
      const timeout=setTimeout(()=>controller.abort(),4500);
      try{
        const shell=await fetch("./",{cache:"no-store",signal:controller.signal});
        if(shell&&shell.ok)await cache.put(OFFLINE_PAGE,shell.clone());
      }finally{
        clearTimeout(timeout);
      }
    }catch(_){}
  })());
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil((async () => {
    if (self.registration.navigationPreload) {
      await self.registration.navigationPreload.enable().catch(() => {});
    }
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter(key => key.startsWith("ipcdj-worship-") && key !== CACHE_NAME)
        .map(key => caches.delete(key))
    );
    await self.clients.claim();
  })());
});

self.addEventListener("message", event => {
  if (event.data && event.data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Freshness probes and explicit in-app refreshes must never be satisfied
  // from the static cache. Always go directly to the network so a refresh
  // can actually see a newly deployed build.
  const isFreshnessRequest =
    url.searchParams.has("refresh") ||
    url.searchParams.has("latest-check") ||
    url.searchParams.has("fresh");

  if (isFreshnessRequest && request.mode !== "navigate") {
    event.respondWith(
      fetch(request, { cache:"no-store" })
        .catch(() => new Response("", { status:504 }))
    );
    return;
  }

  if(request.mode==="navigate"){
    event.respondWith((async()=>{
      const cache=await caches.open(CACHE_NAME);
      const cached=await cache.match(OFFLINE_PAGE);
      const isExplicitFreshNavigation=isFreshnessRequest;

      const networkFetch=async()=>{
        try{
          const preloaded=await event.preloadResponse;
          if(preloaded&&preloaded.ok)return preloaded;
        }catch(_){}

        const controller=new AbortController();
        const timeout=setTimeout(()=>controller.abort(),4500);
        try{
          return await fetch(request,{cache:"no-store",signal:controller.signal});
        }finally{
          clearTimeout(timeout);
        }
      };

      const networkAndCache=async()=>{
        const response=await networkFetch();
        if(response&&response.ok){
          await cache.put(OFFLINE_PAGE,response.clone());
        }
        return response;
      };

      // On a healthy connection prefer the currently deployed shell, which avoids
      // showing one stale app version first and correcting it only after launch.
      // The wait is short and bounded; slow/offline launches still get the cached shell.
      if(!isExplicitFreshNavigation&&cached){
        const networkPromise=networkAndCache().catch(()=>null);
        const fastNetwork=await Promise.race([
          networkPromise,
          new Promise(resolve=>setTimeout(()=>resolve(null),1400))
        ]);

        if(fastNetwork&&fastNetwork.ok)return fastNetwork;

        event.waitUntil(networkPromise.catch(()=>{}));
        return cached;
      }

      try{
        const response=await networkAndCache();
        if(response&&response.ok)return response;
        if(cached)return cached;
        return response;
      }catch(_){
        if(cached)return cached;
        return new Response(
          "<!doctype html><html><body style='font-family:system-ui;background:#0a1020;color:white;padding:24px'>Sin conexión. Intenta actualizar cuando tengas internet.</body></html>",
          {headers:{"Content-Type":"text/html; charset=utf-8"}}
        );
      }
    })());
    return;
  }

  // Static assets: return cached copy immediately, while refreshing it in the background.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request,{ignoreSearch:true});

    const networkPromise = fetch(request, { cache:"no-store" })
      .then(response => {
        if (response && response.ok) {
          cache.put(request, response.clone());
        }
        return response;
      })
      .catch(() => null);

    return cached || await networkPromise || new Response("", { status:504 });
  })());
});


self.addEventListener("push",event=>{
  event.waitUntil((async()=>{
    let raw={};
    try{
      raw=event.data ? event.data.json() : {};
    }catch(_){
      try{ raw={body:event.data?event.data.text():""}; }catch(__){ raw={}; }
    }

    const foundation=self.IPCDJPushFoundation;
    const payload=foundation
      ? foundation.normalizePayload(raw)
      : {
          title:String(raw?.title||"IPCDJ Worship"),
          body:String(raw?.body||""),
          icon:String(raw?.icon||"./icon-192.png?v=9"),
          badge:String(raw?.badge||"./favicon-32.png?v=8"),
          tag:String(raw?.tag||raw?.eventKey||"ipcdj-worship"),
          timestamp:Number(raw?.timestamp)||Date.now(),
          url:String(raw?.url||"./")
        };

    const options=foundation
      ? foundation.toNotificationOptions(payload)
      : {
          body:payload.body,
          icon:payload.icon,
          badge:payload.badge,
          tag:payload.tag,
          timestamp:payload.timestamp,
          data:{url:payload.url}
        };

    // Web Push for IPCDJ is always user-visible. Scheduling/TTL decisions happen
    // server-side so a received push is never used as an invisible background ping.
    await self.registration.showNotification(payload.title||"IPCDJ Worship",options);
  })());
});

self.addEventListener("notificationclick",event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const foundation=self.IPCDJPushFoundation;
    const target=foundation
      ? foundation.notificationTarget(event.notification)
      : String(event.notification?.data?.url||"./");

    const windows=await self.clients.matchAll({type:"window",includeUncontrolled:true});
    for(const client of windows){
      try{
        const url=new URL(client.url);
        if(url.origin!==self.location.origin)continue;
        await client.focus();
        if("navigate" in client)await client.navigate(target).catch(()=>{});
        return;
      }catch(_){}
    }

    if(self.clients.openWindow)await self.clients.openWindow(target);
  })());
});
