import 'dart:js_interop';

/// Web implementation of the push bridge: calls the self-hosted
/// `window.anmatesPush` API (web/push/anmates-push.js). When the script is
/// not on the page (`_push` is null) every method behaves like the no-op
/// stub, and every JS error is swallowed the same way.

/// The JS API surface of web/push/anmates-push.js.
extension type _AnmatesPush._(JSObject _) implements JSObject {
  external bool supported();
  external String permission();
  external bool isIOSNotInstalled();
  external bool isHidden();
  external JSPromise<JSString> enable(JSString vapidKey);
  external JSPromise<JSString> disable();
  external void notifyLocal(JSString title, JSString body, JSString tag);
}

@JS('anmatesPush')
external _AnmatesPush? get _push;

/// Whether this browser can do Web Push at all.
bool pushSupported() {
  final p = _push;
  if (p == null) return false;
  try {
    return p.supported();
  } catch (_) {
    return false;
  }
}

/// Notification permission: 'default' | 'granted' | 'denied' | 'unsupported'.
String pushPermission() {
  final p = _push;
  if (p == null) return 'unsupported';
  try {
    return p.permission();
  } catch (_) {
    return 'unsupported';
  }
}

/// Whether this is an iOS device not installed on the home screen (PWA
/// pushes don't work there, so the UI should steer the user to "add").
bool pushIOSNotInstalled() {
  final p = _push;
  if (p == null) return false;
  try {
    return p.isIOSNotInstalled();
  } catch (_) {
    return false;
  }
}

/// Whether the browser page is currently hidden (background tab).
bool pageHidden() {
  final p = _push;
  if (p == null) return false;
  try {
    return p.isHidden();
  } catch (_) {
    return false;
  }
}

/// Registers the service worker, asks permission and subscribes; returns
/// the subscription JSON string, or null when refused/failed (the JS side
/// signals refusal with '').
Future<String?> pushEnable(String vapidKey) async {
  final p = _push;
  if (p == null) return null;
  try {
    final res = await p.enable(vapidKey.toJS).toDart;
    final s = res.toString();
    return s.isEmpty ? null : s;
  } catch (_) {
    return null;
  }
}

/// Unsubscribes from push; returns the old endpoint, or null.
Future<String?> pushDisable() async {
  final p = _push;
  if (p == null) return null;
  try {
    final res = await p.disable().toDart;
    final s = res.toString();
    return s.isEmpty ? null : s;
  } catch (_) {
    return null;
  }
}

/// Shows a local notification, deduplicated by [tag]. No-op when the
/// script is missing or permission is not granted.
void notifyLocal(String title, String body, String tag) {
  final p = _push;
  if (p == null) return;
  try {
    p.notifyLocal(title.toJS, body.toJS, tag.toJS);
  } catch (_) {}
}
