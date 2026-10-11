# Batwalk public pages

Static privacy policy and support page required by App Store Connect
(App Information › Privacy Policy URL; App Review › Support URL).

Both pages are plain HTML with no scripts or trackers. `index.html` is a one-screen
landing page that links to them.

Published with GitHub Pages by `.github/workflows/pages.yml`:

- https://qianquandong.github.io/Batwalk/privacy.html
- https://qianquandong.github.io/Batwalk/support.html

The workflow runs when `site/` changes on `main`, or by hand (Actions › Pages ›
Run workflow) from any branch that has the folder — the `github-pages` environment
allows `main` and the current review branch. A Cloudflare Pages mirror also works:
`wrangler pages deploy site --project-name batwalk`.

Enter the two URLs in App Store Connect and in `docs/RELEASE_READINESS.md`.
The in-app text in `Apps/Shared/PrivacyView.swift` must say the same things as
`privacy.html`; update both together.
