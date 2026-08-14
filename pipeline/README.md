# Photo pipeline

The website reads its photos from Cloudflare R2 rather than from local disk. This
directory holds the job that puts them there.

```
capture Pi  --(sync_to_r2.py, hourly)-->  R2 bucket  --(img.vilugill.com)-->  browser
     |
     '--(Syncthing, unchanged)--> unraid   # still the full-resolution archive
```

Each photo is published at three sizes, keyed by date:

| Object | Size | Used for |
|---|---|---|
| `full/YYYY-MM-DD.jpg` | ~700 KB | Latest view, maximised view. The original, copied through untouched |
| `web/YYYY-MM-DD.webp` | ~160 KB | The frame you're looking at while scrubbing |
| `thumb/YYYY-MM-DD.webp` | ~22 KB | Preloaded for every photo, so scrubbing is instant |
| `photos.json` | ~9 KB | The index. R2 has no directory listing, so this replaces nginx's autoindex |

Whole-set totals at 713 photos: roughly 520 MB full, 110 MB web, 15 MB thumb —
about 650 MB against R2's 10 GB free tier, growing ~1 MB a day.

## Why three sizes

The page preloads the entire timelapse so the slider is instant. At full size
that was 463 MB per visitor. At thumbnail size it's about 15 MB, and the sharper
image is fetched only for the frame you actually land on.

---

## One-time Cloudflare setup

> **Use Oli's personal Cloudflare account**, not the one Korvi lives on.
> Check with `npx wrangler whoami` before creating anything.

### 1. Log in and confirm the account

```bash
npx wrangler login
```

```bash
npx wrangler whoami
```

Note the Account ID for the personal account. Export it so nothing can drift:

```bash
export CLOUDFLARE_ACCOUNT_ID=<personal-account-id>
```

### 2. Create the bucket

Location hint `eeur` puts it in Eastern Europe, nearest the house and most
visitors. This can only be set at creation.

```bash
npx wrangler r2 bucket create vilugill-photos --location eeur
```

### 3. Move DNS to Cloudflare

In the dashboard: **Add a site** → `vilugill.com` → Free plan → let it import the
existing records. Then at Namecheap, change the nameservers from
`dns1/dns2.registrar-servers.com` to the pair Cloudflare gives you.

Registration stays at Namecheap; only DNS moves. Propagation is usually minutes.
Check the existing A record for the house server is still there afterwards.

### 4. Attach the image domain

**R2 → vilugill-photos → Settings → Custom Domains → Connect Domain** →
`img.vilugill.com`. Cloudflare creates the DNS record itself.

Leave the `r2.dev` public URL **disabled** — it's rate limited and throttles
exactly the burst of requests the timelapse makes.

### 5. Allow the site to read the index

`photos.json` is loaded with `fetch()`, so it's subject to CORS. Images in
`<img>` tags aren't, but the index is. Without this the site loads no photos.

**R2 → vilugill-photos → Settings → CORS Policy**:

```json
[
  {
    "AllowedOrigins": [
      "https://vilugill.com",
      "https://www.vilugill.com"
    ],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 86400
  }
]
```

Add `http://localhost:8899` too if you want to run the site locally against the
real bucket.

### 6. Create an API token for the Pi

**R2 → API → Manage API tokens → Create token**, scoped to
**Object Read & Write** on `vilugill-photos` only. Keep the Access Key ID and
Secret — the secret is shown once.

---

## Pi setup (Docker)

Credentials live in one file, readable only by its owner:

```bash
mkdir -p ~/vilugill && install -m 600 /dev/null ~/vilugill/r2.env
```

`~/vilugill/r2.env` — plain `KEY=value` lines, no quotes and no `export`,
because Docker's `--env-file` takes the text literally:

```
R2_ACCOUNT_ID=<personal-account-id>
R2_ACCESS_KEY_ID=<access-key-id>
R2_SECRET_ACCESS_KEY=<secret>
R2_BUCKET=vilugill-photos
```

Build the image on the Pi:

```bash
git clone https://github.com/olig89/plot-timelapse.git ~/vilugill/plot-timelapse
```

```bash
docker build -t vilugill-sync ~/vilugill/plot-timelapse/pipeline
```

### Check it before it writes anything

```bash
docker run --rm --env-file ~/vilugill/r2.env -v /path/to/photos:/photos:ro vilugill-sync --dry-run
```

That reports what it would upload and touches nothing.

### Backfill

The first real run uploads everything. Same command without `--dry-run`, and
it's resumable — if it dies, run it again and it picks up whatever is still
missing.

```bash
docker run --rm --env-file ~/vilugill/r2.env -v /path/to/photos:/photos:ro vilugill-sync
```

Expect roughly 650 MB of upload and, on a Pi 4, a while for the resizing. Worth
starting with `--limit 5` to confirm the objects land where you expect, then
letting the rest run overnight. If the Pi doesn't hold the full history, run the
same job anywhere that does — it only needs the photo directory and the env
file.

### Hourly run

```bash
crontab -e
```

```cron
# Publish new house photos to R2. Hourly rather than daily so a late or missed
# capture still gets picked up the same day.
17 * * * * /usr/bin/docker run --rm --env-file $HOME/vilugill/r2.env -v /path/to/photos:/photos:ro vilugill-sync >> $HOME/vilugill/sync.log 2>&1
```

A run with nothing to do costs three list requests and rewrites the index; the
free tier allows a million such operations a month.

### Without Docker

If you'd rather run it on the host:

```bash
sudo apt install -y python3-pil python3-boto3
```

Then `sync_to_r2.py` directly, sourcing the same file:

```bash
set -a; . ~/vilugill/r2.env; set +a; ./sync_to_r2.py --photo-dir /path/to/photos --dry-run
```

---

## Options

| Flag | Effect |
|---|---|
| `--photo-dir` | Where the source photos are (required) |
| `--dry-run` | Report only, change nothing |
| `--limit N` | Only publish the N oldest missing photos |
| `--force` | Re-generate and re-upload everything, ignoring what's already there |
| `--workers N` | Parallel uploads, default 4 |
| `--bucket` | Override `R2_BUCKET` |

## Filenames

Source photos are matched on a leading date, so `2026-08-14-10.jpg`,
`2026-08-14-n.jpg` and `2026-08-14.jpg` are all accepted and all publish as
`2026-08-14`. The original filename is kept on the object as `source-filename`
metadata, since the date-based key discards the capture-time suffix.

One photo per date. If a date somehow has two files, the last one alphabetically
wins.
