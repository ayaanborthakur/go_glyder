importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDGVB07YMExQstGolch-cZIrSTpuojAuO8',
  authDomain: 'trydentlabs-goglyder.firebaseapp.com',
  projectId: 'trydentlabs-goglyder',
  storageBucket: 'trydentlabs-goglyder.firebasestorage.app',
  messagingSenderId: '163214469630',
  appId: '1:163214469630:web:08fe2ebc779f536a8178af',
});

const messaging = firebase.messaging();

// Handle background messages (tab not in focus)
messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(
    payload.notification?.title || 'GoGlyder',
    {
      body: payload.notification?.body || '',
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: payload.data, // carries route + convId for tap handling
    }
  );
});

// Route the user on notification click
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification.data?.route || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      // Focus existing tab if open
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          // If you want to use postMessage to route without reload:
          // client.postMessage({ type: 'NOTIFICATION_CLICK', route });
          // But a simple focus is safer for now.
          return client.focus();
        }
      }
      // Or open a new window to the specific route
      if (clients.openWindow) return clients.openWindow(self.location.origin + route);
    })
  );
});
