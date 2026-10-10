// =============================================================================
// FILE: web/firebase-messaging-sw.js
// Firebase Cloud Messaging Service Worker for background Web Push notifications
// Runs in the browser background even when the CapSync web tab is closed.
// =============================================================================

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBT_agnDiPAd3J7qRLu-UHcjDt8vPO3snU",
  authDomain: "capsync-813b5.firebaseapp.com",
  projectId: "capsync-813b5",
  storageBucket: "capsync-813b5.firebasestorage.app",
  messagingSenderId: "108120561521",
  appId: "1:108120561521:web:faa3c61a2b55a128f4c8d0",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);

  const notificationTitle = payload.notification?.title || payload.data?.title || 'CapSync Alert';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'You have an academic consultation update in CapSync.',
    icon: 'favicon.png',
    badge: 'favicon.png',
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
