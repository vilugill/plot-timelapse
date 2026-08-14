# Plot Timelapse

The house-build timelapse behind [vilugill.com](https://vilugill.com) — a daily
photo of the plot, with a scrubbable timeline going back to the first day.

Vanilla HTML/CSS/JS, no framework, no build step.

```
src/        the website
pipeline/   the job that publishes photos to Cloudflare R2 (see pipeline/README.md)
```

## How it works

A camera on a Raspberry Pi takes one photo a day. The Pi publishes it to a
Cloudflare R2 bucket at three sizes and rewrites `photos.json`, the index the
site reads. The site itself is static and hosted on Cloudflare Pages, so nothing
on the home network is in the path when someone visits.

Syncthing still mirrors the originals to unraid — that remains the archive.

## Local development

```bash
cd src && python -m http.server 8899
```

The site then loads photos from the live R2 bucket, which needs
`http://localhost:8899` in the bucket's CORS policy (see `pipeline/README.md`).
To work fully offline, drop some `YYYY-MM-DD` photos in a folder, generate the
tiers locally, and set `PHOTO_BASE` in `src/script.js` to `''`.

## Deploying the site

```bash
npx wrangler pages deploy src --project-name vilugill
```

Use Oli's personal Cloudflare account, not the one Korvi lives on — check with
`npx wrangler whoami` first.

The first deploy creates the project; afterwards, point `vilugill.com` at it
under **Workers & Pages → vilugill → Custom domains**.

## Configuration

Everything tunable is at the top of `src/script.js`:

| Constant | Purpose |
|---|---|
| `PHOTO_BASE` | Where the photos are served from |
| `DEFAULT_TIERS` | Fallback tier layout if `photos.json` doesn't declare one |
| `WEB_PREFETCH_WINDOW` | How many photos either side of the current one to fetch sharp |
| `PRELOAD_CONCURRENCY` | Thumbnails downloaded at once during the initial preload |

## Photo requirements

Named with a leading date: `2026-08-14.jpg`, `2026-08-14-10.jpg` and
`2026-08-14-n.jpg` are all fine. JPG or PNG. One per day.

## Legacy

`Dockerfile`, `nginx.conf` and `docker-compose.yml` are the old self-hosted
setup, where nginx served both the site and the photos from unraid and the app
discovered photos by parsing nginx's autoindex HTML. Kept as a fallback; the
live site no longer uses them.

`setup.sh` used to generate the whole app from scratch, but it only ever
generated the original v1.0 UI — running it would have overwritten the real site.
Removed in the R2 migration; recoverable from commit `4869201` if ever needed.
