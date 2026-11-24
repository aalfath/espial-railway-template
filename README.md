[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/espial?utm_medium=integration&utm_source=button&utm_campaign=espial)

# Deploy and Host Espial on Railway

Espial is an open-source, web-based bookmarking server. You save links with a title, description and tags, search and filter them, mark them read later or starred, keep plain-text notes, and choose per bookmark whether it is private or shown on your public profile. It stores everything in one SQLite database and supports several user accounts.

## About Hosting Espial

This template runs Espial 0.0.42 from the official `jonschoning/espial` image, pinned by version and digest, as one Railway service with a volume at `/app/data` for the SQLite database and the session key. Espial has no sign-up page, so on first boot the start script creates your owner account from `ESPIAL_USERNAME` (default `admin`) and a generated `ESPIAL_PASSWORD` before the port opens; it refuses to start without a password of at least 12 characters. After deploying, open the service's Variables tab, copy `ESPIAL_PASSWORD`, and log in at your Railway URL. Changing the variable later does not change the password; use Settings → Change Password in the app. It runs within the Free plan's 0.5 GB.

## Common Use Cases

* A private, searchable bookmark collection you add to from any browser with the bookmarklet
* A public link blog: share selected bookmarks and notes on your profile page and its RSS feed
* Moving off Pinboard, Firefox or browser bookmark exports into a self-hosted archive

## Dependencies for Espial Hosting

* One Railway service built from this repository (no external database: SQLite on a Railway volume)
* A Railway volume mounted at `/app/data`

### Deployment Dependencies

* Espial source and documentation: https://github.com/jonschoning/espial
* Espial 0.0.42 release: https://github.com/jonschoning/espial/releases/tag/v0.0.42
* Official image: https://hub.docker.com/r/jonschoning/espial
* Template repository: https://github.com/aalfath/espial-railway-template

### Implementation Details

Services in this template:

* **Espial**: the web app on Railway's `PORT` (8080), health check `/auth/login`, volume `/app/data` (database `espial.sqlite3` and `client_session_key`, so logins survive redeploys).

Variables:

| Variable | Default | What it does |
|---|---|---|
| `ESPIAL_USERNAME` | `admin` | Owner account created on first boot (letters, digits, `.`, `_`, `-`) |
| `ESPIAL_PASSWORD` | generated, 24 characters | Owner password, used only on first boot |
| `APPROOT` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL Espial uses for links and redirects; set it to `https://YOUR-DOMAIN` if you add a custom domain |
| `PORT` | `8080` | Port Espial listens on |

After you log in:

* **Add bookmarks** with the bookmarklet on the Settings page, or import JSON, Firefox or Netscape (browser export) files under Settings → Import / Export (10 MB per upload).
* **API key**: Settings → API key creates a key for the `/api/add` endpoint and the Android share app.
* **More users**: open the service shell (`railway ssh`) and run `./migration createuser --userName NAME --userPassword 'PASSWORD'`.
* **Not included**: the optional ArchiveBox or Wayback Machine page archiving (the archive backend is off), and SMTP (Espial sends no mail).

Updates: the service builds from this repository, so Railway shows you an "update available" notice when we bump the pinned Espial version here. Read `CHANGELOG.md` before you apply it. Database migrations run on each start.

The start script also sets Espial's runtime threads from the service's CPU quota, trusts Railway's `X-Real-IP` header for the login rate limit (`IP_FROM_HEADER=true`), marks the session cookie Secure (`SSL_ONLY=true`), and exits non-zero if Espial stops, so Railway's restart policy brings it back.

## Why Deploy Espial on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Espial on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
