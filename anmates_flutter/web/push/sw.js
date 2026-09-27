// AnMates self-hosted push service worker.
// Lives at /push/sw.js with scope /push/ so it never collides with a
// Flutter service worker registered at scope "/".

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
  var payload = {
    id: '',
    kind: 'generic',
    title: 'ĂnMates',
    body: 'Bạn có thông báo mới',
    url: ''
  };
  if (event.data) {
    try {
      var data = event.data.json();
      if (data) {
        payload = Object.assign(payload, data);
      }
    } catch (e) {
      console.warn('[anmatesPush]', e);
    }
  }
  event.waitUntil(
    self.registration.showNotification(payload.title || 'ĂnMates', {
      body: payload.body || 'Bạn có thông báo mới',
      tag: payload.id || payload.kind,
      renotify: true,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: { url: payload.url || '/' }
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  var url =
    event.notification.data && event.notification.data.url
      ? event.notification.data.url
      : '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (windows) {
      if (windows.length > 0) {
        return windows[0].focus();
      }
      return self.clients.openWindow(url);
    })
  );
});
