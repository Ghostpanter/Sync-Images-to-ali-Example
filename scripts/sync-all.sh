#!/usr/bin/env bash
# Read image.txt, keep only this shard's lines, copy in parallel.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${ROOT}/image.txt"
ONE="${ROOT}/scripts/sync-one.sh"
SHARD_ID="${SHARD_ID:-0}"
SHARD_COUNT="${SHARD_COUNT:-1}"
PARALLEL="${PARALLEL:-3}"

[ -f "$LIST" ] || { echo "missing ${LIST}"; exit 1; }
chmod +x "$ONE" || true

mapfile -t LINES < <(
  awk -v id="$SHARD_ID" -v n="$SHARD_COUNT" '
    {
      raw=$0
      sub(/#.*/, "", raw)
      gsub(/^[ \t]+|[ \t]+$/, "", raw)
      if (raw == "") next
      if (i % n == id) print raw
      i++
    }
  ' "$LIST"
)

echo "shard ${SHARD_ID}/${SHARD_COUNT} images=${#LINES[@]} parallel=${PARALLEL}"
[ "${#LINES[@]}" -gt 0 ] || { echo "nothing in this shard"; exit 0; }

fail=0
printf '%s\n' "${LINES[@]}" | xargs -r -P "$PARALLEL" -I{} bash "$ONE" {}
exit $?
