// Non-web (Android/iOS) implementation of the push bridge: everything is a
// no-op until a native push backend is wired in.

/// Whether this platform can do push (the stub cannot).
bool pushSupported() => false;

/// Notification permission: 'default' | 'granted' | 'denied' | 'unsupported'.
String pushPermission() => 'unsupported';

/// Whether this is an iOS device not installed on the home screen (always
/// false off the web, where no PWA install state exists).
bool pushIOSNotInstalled() => false;

/// Whether the page/app is hidden (false off the web).
bool pageHidden() => false;

/// Enable push; returns the subscription JSON string, or null (the stub
/// always returns null).
Future<String?> pushEnable(String vapidKey) async => null;

/// Disable push; returns the old endpoint, or null.
Future<String?> pushDisable() async => null;

/// Show a local notification (no-op off the web).
void notifyLocal(String title, String body, String tag) {}
