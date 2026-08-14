#!/usr/bin/env python3
"""Publish daily house-build photos to Cloudflare R2.

Runs on the capture Pi. For every photo that isn't in the bucket yet it
generates three sizes, uploads them, and rewrites the manifest the website
reads (R2 has no directory listing, so the index has to be a real object).

Safe to re-run: it compares local dates against what's already in the bucket
and only does the missing work. A first run therefore doubles as the backfill.

    ./sync_to_r2.py --photo-dir ~/timelapse
    ./sync_to_r2.py --photo-dir ~/timelapse --dry-run
"""

import argparse
import io
import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

try:
    import boto3
    from botocore.config import Config
    from botocore.exceptions import ClientError
except ImportError:
    sys.exit("boto3 is missing. Install it with: pip3 install boto3")

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.exit("Pillow is missing. Install it with: pip3 install Pillow")


# Photos are named by the day they were taken; anything after the date (a
# capture time, a note) is ignored, and the date alone becomes the object key.
FILENAME_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2})(?:[-_. ].*)?\.(jpe?g|png)$", re.IGNORECASE)

# Sizes the website asks for. "full" is the original, copied through untouched:
# the source is already 1920px and re-encoding it to WebP saves under 10% while
# costing a generation of quality.
TIERS = {
    "thumb": {"dir": "thumb", "ext": "webp", "width": 400, "quality": 70},
    "web": {"dir": "web", "ext": "webp", "width": 960, "quality": 78},
    "full": {"dir": "full", "ext": "jpg", "width": None, "quality": None},
}

# Not "manifest.json": the website already ships a PWA manifest under that name
MANIFEST_KEY = "photos.json"

# Individual photos never change once published, so they can be cached hard.
# The manifest has to turn over quickly or a new day's photo won't appear.
IMMUTABLE_CACHE = "public, max-age=31536000, immutable"
MANIFEST_CACHE = "public, max-age=300"

CONTENT_TYPES = {"webp": "image/webp", "jpg": "image/jpeg", "png": "image/png"}


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--photo-dir", required=True, type=Path,
                        help="Directory holding the source photos")
    parser.add_argument("--bucket", default=os.environ.get("R2_BUCKET", "vilugill-photos"))
    parser.add_argument("--workers", type=int, default=4,
                        help="Parallel uploads (default 4; the Pi is the bottleneck, not R2)")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only process this many missing photos, oldest first")
    parser.add_argument("--dry-run", action="store_true",
                        help="Report what would be uploaded, change nothing")
    parser.add_argument("--force", action="store_true",
                        help="Re-generate and re-upload even if already present")
    return parser.parse_args()


def make_client():
    """S3-compatible client pointed at R2."""
    account_id = os.environ.get("R2_ACCOUNT_ID")
    access_key = os.environ.get("R2_ACCESS_KEY_ID")
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY")

    missing = [name for name, value in [
        ("R2_ACCOUNT_ID", account_id),
        ("R2_ACCESS_KEY_ID", access_key),
        ("R2_SECRET_ACCESS_KEY", secret_key),
    ] if not value]
    if missing:
        sys.exit(f"Missing environment variable(s): {', '.join(missing)}")

    return boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(retries={"max_attempts": 5, "mode": "standard"}),
    )


def find_local_photos(photo_dir):
    """Map date -> source file, newest name winning if a date somehow repeats."""
    found = {}
    for path in sorted(photo_dir.iterdir()):
        if not path.is_file():
            continue
        match = FILENAME_PATTERN.match(path.name)
        if match:
            found[match.group(1)] = path
    return found


def list_published_dates(client, bucket):
    """Dates that already have every tier present in the bucket."""
    per_tier = {}
    paginator = client.get_paginator("list_objects_v2")

    for tier_name, tier in TIERS.items():
        dates = set()
        for page in paginator.paginate(Bucket=bucket, Prefix=f"{tier['dir']}/"):
            for obj in page.get("Contents", []):
                stem = Path(obj["Key"]).stem
                if re.fullmatch(r"\d{4}-\d{2}-\d{2}", stem):
                    dates.add(stem)
        per_tier[tier_name] = dates

    return set.intersection(*per_tier.values()) if per_tier else set()


def render_tier(source_path, tier):
    """Return the bytes to upload for one tier."""
    if tier["width"] is None:
        return source_path.read_bytes()

    with Image.open(source_path) as img:
        # Honour any EXIF orientation before resizing, then drop the metadata
        img = ImageOps.exif_transpose(img)
        img = img.convert("RGB")

        height = round(img.height * tier["width"] / img.width)
        img = img.resize((tier["width"], height), Image.LANCZOS)

        buffer = io.BytesIO()
        img.save(buffer, "WEBP", quality=tier["quality"], method=6)
        return buffer.getvalue()


def publish_photo(client, bucket, date, source_path, dry_run):
    """Generate and upload every tier for one date. Returns bytes uploaded."""
    uploaded = 0

    for tier in TIERS.values():
        key = f"{tier['dir']}/{date}.{tier['ext']}"
        payload = render_tier(source_path, tier)
        uploaded += len(payload)

        if dry_run:
            continue

        client.put_object(
            Bucket=bucket,
            Key=key,
            Body=payload,
            ContentType=CONTENT_TYPES[tier["ext"]],
            CacheControl=IMMUTABLE_CACHE,
            # Keep a breadcrumb back to the original filename, which carries the
            # capture time that the date-based key throws away
            Metadata={"source-filename": source_path.name},
        )

    return uploaded


def write_manifest(client, bucket, dates, dry_run):
    """Rewrite the index the website reads."""
    manifest = {
        "version": 1,
        "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "count": len(dates),
        "tiers": {name: {"dir": t["dir"], "ext": t["ext"], "width": t["width"]}
                  for name, t in TIERS.items()},
        "dates": sorted(dates),
    }
    body = json.dumps(manifest, separators=(",", ":")).encode("utf-8")

    if not dry_run:
        client.put_object(
            Bucket=bucket,
            Key=MANIFEST_KEY,
            Body=body,
            ContentType="application/json",
            CacheControl=MANIFEST_CACHE,
        )

    return len(body)


def main():
    args = parse_args()

    if not args.photo_dir.is_dir():
        sys.exit(f"Photo directory not found: {args.photo_dir}")

    client = make_client()

    local = find_local_photos(args.photo_dir)
    if not local:
        sys.exit(f"No date-named photos found in {args.photo_dir}")

    try:
        published = set() if args.force else list_published_dates(client, args.bucket)
    except ClientError as error:
        sys.exit(f"Could not read the bucket: {error}")

    pending = sorted(set(local) - published)
    if args.limit:
        pending = pending[:args.limit]

    print(f"{len(local)} photos on disk, {len(published)} already published, {len(pending)} to do")

    if not pending:
        # Still refresh the manifest: it may be missing or out of date even when
        # every image is present
        size = write_manifest(client, args.bucket, sorted(local), args.dry_run)
        print(f"Manifest refreshed ({size} bytes, {len(local)} dates)")
        return

    total_bytes = 0
    failures = []

    def work(date):
        try:
            return date, publish_photo(client, args.bucket, date, local[date], args.dry_run)
        except Exception as error:  # keep going; one bad file shouldn't stop the run
            return date, error

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for index, (date, result) in enumerate(pool.map(work, pending), start=1):
            if isinstance(result, Exception):
                failures.append((date, result))
                print(f"  [{index}/{len(pending)}] {date} FAILED: {result}")
            else:
                total_bytes += result
                print(f"  [{index}/{len(pending)}] {date} ({result / 1024:.0f} KB)")

    succeeded = {date for date in pending if date not in {d for d, _ in failures}}
    manifest_dates = sorted(published | succeeded)

    size = write_manifest(client, args.bucket, manifest_dates, args.dry_run)

    prefix = "[dry run] " if args.dry_run else ""
    print(f"{prefix}Uploaded {total_bytes / 1024 / 1024:.1f} MB across {len(succeeded)} photos")
    print(f"{prefix}Manifest now lists {len(manifest_dates)} dates ({size} bytes)")

    if failures:
        print(f"\n{len(failures)} photo(s) failed:", file=sys.stderr)
        for date, error in failures:
            print(f"  {date}: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
