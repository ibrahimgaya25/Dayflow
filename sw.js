/* DayFlow service worker: lets the app open with no internet connection.
   Upload this file next to index.html. Change the version below when you
   want every phone to drop its saved copy and fetch everything again. */
const CACHE = 'dayflow-v1';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icon-180.png', 'icon-192.png', 'icon-512.png'];

self.addEventListener('install', event => {
  // each file is saved on its own, so one missing file does not stop the rest
  event.waitUntil(caches.open(CACHE)
    .then(cache => Promise.all(SHELL.map(url => cache.add(url).catch(() => {}))))
    .then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys()
    .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const isPage = req.mode === 'navigate' || (url.origin === self.location.origin && /(\/|index\.html)$/.test(url.pathname));

  if (isPage) {
    // the page itself: newest version when online, the saved copy when offline
    event.respondWith(fetch(req)
      .then(res => { if (res.ok) { const copy = res.clone(); caches.open(CACHE).then(c => c.put('index.html', copy)); } return res; })
      .catch(() => caches.match('index.html').then(hit => hit || caches.match('./'))));
    return;
  }
  // icons and fonts: the saved copy first, the network if there is none yet
  event.respondWith(caches.match(req).then(hit => hit || fetch(req).then(res => {
    if (res && (res.ok || res.type === 'opaque')) { const copy = res.clone(); caches.open(CACHE).then(c => c.put(req, copy)); }
    return res;
  })));
});
