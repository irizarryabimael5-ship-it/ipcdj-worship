const CACHE_NAME = "ipcdj-worship-v99";
const OFFLINE_PAGE = "./__offline_index__";
const STATIC_ASSETS = [
  "./favicon.svg",
  "./favicon-32.png",
  "./favicon.ico",
  "./apple-touch-icon.png",
  "./app-icon-safe.svg",
  "./icon-192.png",
  "./icon-512.png",
  "./icon-maskable-512.png",
  "./spotify.svg",
  "./apple-music.svg",
  "./youtube-music.svg"
];

self.addEventListener("install",event=>{
  event.waitUntil((async()=>{
    const cache=await caches.open(CACHE_NAME);
    await cache.addAll(STATIC_ASSETS);
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

      // Normal opens prioritize instant startup from the last verified shell.
      // Refresh/freshness navigations prioritize network, but are still bounded.
      if(!isExplicitFreshNavigation&&cached){
        event.waitUntil(
          networkFetch().then(async response=>{
            if(response&&response.ok){
              await cache.put(OFFLINE_PAGE,response.clone());
            }
          }).catch(()=>{})
        );
        return cached;
      }

      try{
        const response=await networkFetch();
        if(response&&response.ok){
          await cache.put(OFFLINE_PAGE,response.clone());
          return response;
        }
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
    const cached = await cache.match(request);

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
