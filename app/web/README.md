# Web

Run `flutter create . --platforms=web` from `app/` to add icons/manifest; `index.html`,
`logout.html` and `vercel.json` here are kept and copied into `build/web` by `flutter build web`.

Build and deploy (Vercel has no Flutter toolchain, so deploy the prebuilt static output):

```bash
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.production.json
vercel deploy build/web --prod
```

`--no-web-resources-cdn` self-hosts CanvasKit so the CSP can stay `script-src 'self'`.
Replace `REPLACE_WITH_API_HOST` in `vercel.json` (CSP `connect-src`) with the API host, and pin
`*.supabase.co` to your exact project host.
