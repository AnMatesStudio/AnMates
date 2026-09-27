// AnMates self-hosted push: tiny page API the Dart app calls through JS interop.
// No build step, no third-party scripts. All methods are safe to call and
// never throw (errors are logged with console.warn('[anmatesPush]', e)).

(function () {
  'use strict';

  var SW_PATH = '/push/sw.js';
  var SW_SCOPE = '/push/';
  var ICON = '/icons/Icon-192.png';

  function urlB64ToUint8Array(s) {
    var padded = s + '==='.slice(0, (4 - (s.length % 4)) % 4);
    var b64 = padded.replace(/-/g, '+').replace(/_/g, '/');
    var bin = atob(b64);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) {
      bytes[i] = bin.charCodeAt(i);
    }
    return bytes;
  }

  function getPushRegistration() {
    return navigator.serviceWorker.getRegistration(SW_SCOPE);
  }

  function supported() {
    try {
      return (
        'serviceWorker' in navigator &&
        'PushManager' in window &&
        'Notification' in window
      );
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return false;
    }
  }

  function permission() {
    try {
      if (!('Notification' in window)) return 'unsupported';
      return Notification.permission;
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return 'unsupported';
    }
  }

  function isIOSNotInstalled() {
    try {
      var iosDevice = /iPad|iPhone|iPod/.test(navigator.userAgent);
      var standalone =
        window.navigator.standalone ||
        matchMedia('(display-mode: standalone)').matches;
      return iosDevice && !standalone;
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return false;
    }
  }

  function isHidden() {
    try {
      return document.visibilityState === 'hidden';
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return false;
    }
  }

  // Registers /push/sw.js (waiting for activation if needed), asks for
  // notification permission, subscribes to push, and returns the
  // subscription as a JSON string ('' when permission is not granted).
  async function enable(vapidKeyB64u) {
    try {
      var reg = await navigator.serviceWorker.register(SW_PATH, { scope: SW_SCOPE });
      if (!reg.active) {
        var worker = reg.installing || reg.waiting;
        if (worker) {
          // Do NOT use navigator.serviceWorker.ready here: it only resolves
          // for a worker controlling this page's scope, and ours does not.
          await new Promise(function (resolve, reject) {
            worker.addEventListener('statechange', function () {
              if (worker.state === 'activated') {
                resolve();
              } else if (worker.state === 'redundant') {
                reject(new Error('service worker failed to activate'));
              }
            });
          });
        }
      }
      var perm = await Notification.requestPermission();
      if (perm !== 'granted') return '';
      var sub = await reg.pushManager.getSubscription();
      if (!sub) {
        sub = await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlB64ToUint8Array(vapidKeyB64u)
        });
      }
      return JSON.stringify(sub.toJSON());
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return '';
    }
  }

  // Unsubscribes the /push/ registration. Returns the old endpoint or ''.
  async function disable() {
    try {
      var reg = await getPushRegistration();
      if (!reg) return '';
      var sub = await reg.pushManager.getSubscription();
      if (sub) {
        await sub.unsubscribe();
      }
      return sub ? sub.endpoint : '';
    } catch (e) {
      console.warn('[anmatesPush]', e);
      return '';
    }
  }

  // Shows a local (Web Push-less) notification. Never throws.
  async function notifyLocal(title, body, tag) {
    try {
      if (permission() !== 'granted') return;
      var reg = await getPushRegistration();
      if (reg) {
        await reg.showNotification(title, {
          body: body,
          tag: tag,
          icon: ICON
        });
      } else {
        new Notification(title, { body: body, tag: tag, icon: ICON });
      }
    } catch (e) {
      console.warn('[anmatesPush]', e);
    }
  }

  window.anmatesPush = {
    supported: supported,
    permission: permission,
    isIOSNotInstalled: isIOSNotInstalled,
    isHidden: isHidden,
    enable: enable,
    disable: disable,
    notifyLocal: notifyLocal
  };
})();
