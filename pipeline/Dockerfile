# Sync job for the capture Pi. Built and run on the Pi itself, so it picks up
# the right architecture automatically.
#
#   docker build -t vilugill-sync ./pipeline
#   docker run --rm --env-file r2.env -v /path/to/photos:/photos:ro vilugill-sync
#
# Extra arguments are passed straight through, so --dry-run and friends work:
#   docker run --rm --env-file r2.env -v /path/to/photos:/photos:ro vilugill-sync --dry-run

FROM python:3.12-slim

# Pillow and boto3 ship prebuilt wheels for 64-bit ARM, so this needs no compiler
RUN pip install --no-cache-dir pillow boto3

WORKDIR /app
COPY sync_to_r2.py /app/

# Photos are mounted read-only at /photos; the job only ever reads them
ENTRYPOINT ["python", "/app/sync_to_r2.py", "--photo-dir", "/photos"]
