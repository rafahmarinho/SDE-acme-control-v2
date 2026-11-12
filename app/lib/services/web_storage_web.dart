import 'package:web/web.dart' as web;

/// Clears local/session storage for this origin and navigates to /logout.html, which is served
/// with `Clear-Site-Data: "cache", "storage"` (see app/vercel.json) and then returns to the app.
void clearBrowserStorageAndReload() {
  web.window.localStorage.clear();
  web.window.sessionStorage.clear();
  web.window.location.assign('/logout.html');
}
