// Flutter caches the app bundle; Firebase loads its SDK from gstatic at runtime.
// Cache those SDK responses too so a previously opened app can restart offline.
importScripts('flutter_service_worker.js');

const firebaseSdkCache = 'quotation-firebase-sdk-v1';
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' ||
      url.hostname !== 'www.gstatic.com' ||
      !url.pathname.startsWith('/firebasejs/')) return;
  event.respondWith((async () => {
    const cache = await caches.open(firebaseSdkCache);
    const cached = await cache.match(event.request);
    if (cached) return cached;
    const response = await fetch(event.request);
    if (response.ok || response.type === 'opaque') {
      await cache.put(event.request, response.clone());
    }
    return response;
  })());
});
