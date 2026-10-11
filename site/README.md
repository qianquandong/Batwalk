# Batwalk public pages

Static privacy policy and support page required by App Store Connect
(App Information › Privacy Policy URL; App Review › Support URL).

Both pages are plain HTML with no scripts or trackers. Publish the folder
anywhere static; two free options that work from a phone browser:

- **Cloudflare Pages** — `wrangler pages deploy site --project-name batwalk`
  (the account already has `cloudflared` set up), or connect this repo in the
  Cloudflare dashboard with build output directory `site`.
- **GitHub Pages** — needs a public repo (Pages on a private repo requires GitHub Pro):
  push `site/` to a `batwalk-site` repo and enable Pages from its root.

Then enter the two URLs in App Store Connect and in `docs/RELEASE_READINESS.md`.
The in-app text in `Apps/Shared/PrivacyView.swift` must say the same things as
`privacy.html`; update both together.
