const CACHE_NAME = "ipcdj-worship-v12";
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

self.addEventListener("install", event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key.startsWith("ipcdj-worship-") && key !== CACHE_NAME)
          .map(key => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

self.addEventListener("message", event => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request, { cache:"no-store" })
        .then(async response => {
          if(response && response.ok){
            const cache=await caches.open(CACHE_NAME);
            await cache.put(OFFLINE_PAGE,response.clone());
          }
          return response;
        })
        .catch(async () => {
          const cached=await caches.match(OFFLINE_PAGE);
          return cached || new Response(
            "<!doctype html><html><body style='font-family:system-ui;background:#0a1020;color:white;padding:24px'>Sin conexión. Intenta actualizar cuando tengas internet.</body></html>",
            {headers:{"Content-Type":"text/html; charset=utf-8"}}
          );
        })
    );
    return;
  }

  event.respondWith(
    fetch(request, { cache:"no-cache" })
      .then(async response => {
        if(response && response.ok){
          const cache=await caches.open(CACHE_NAME);
          await cache.put(request,response.clone());
        }
        return response;
      })
      .catch(()=>caches.match(request))
  );
});
