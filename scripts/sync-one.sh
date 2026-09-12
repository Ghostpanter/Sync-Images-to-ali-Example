#!/usr/bin/env bash
# Sync one image line to ACR.
# Incremental: skip when source digest already matches dest tag.
# Keep old tag: when dest exists and digest changes, copy dest to dest:prev-YYYYmmdd-HHMMSS
# and dest:<short-digest> before overwriting the working tag.
set -euo pipefail

ACR_REGISTRY="${ACR_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
ACR_NAMESPACE="${ACR_NAMESPACE:-kkun}"
OS="${SYNC_OS:-linux}"
ARCH="${SYNC_ARCH:-amd64}"

line="${1:-}"
line="${line%%#*}"
line="$(echo "$line" | xargs)"
[ -z "$line" ] && exit 0

src="$(echo "$line" | awk '{print $1}')"
dest_name="$(echo "$line" | awk '{print $2}')"
if [ -z "$dest_name" ]; then
  dest_name="${src##*/}"
fi

dst="${ACR_REGISTRY}/${ACR_NAMESPACE}/${dest_name}"
repo="${dst%:*}"
if [[ "$dst" != *:* ]] || [[ "$dst" == */* ]] && [[ "$dst" != *:*:* ]] && [[ "${dst##*/}" != *:* ]]; then
  # no explicit tag on dest; skopeo treats as implicit latest
  dest_tag="latest"
  dest_ref="${dst}"
else
  dest_tag="${dst##*:}"
  dest_ref="${dst}"
  repo="${dst%:*}"
fi

# Normalize repo when dest_name already includes tag (nginx:latest)
if [[ "$dest_name" == *:* ]]; then
  dest_tag="${dest_name##*:}"
  dest_repo_name="${dest_name%:*}"
  repo="${ACR_REGISTRY}/${ACR_NAMESPACE}/${dest_repo_name}"
  dest_ref="${repo}:${dest_tag}"
else
  dest_tag="latest"
  repo="${ACR_REGISTRY}/${ACR_NAMESPACE}/${dest_name}"
  dest_ref="${repo}:${dest_tag}"
fi

echo "==== ${src} -> ${dest_ref} (${OS}/${ARCH}) ===="

digest_of() {
  skopeo inspect \
    --override-os "$OS" \
    --override-arch "$ARCH" \
    "docker://${1}" \
    --format '{{.Digest}}' 2>/dev/null || true
}

src_digest="$(digest_of "$src")"
if [ -z "$src_digest" ]; then
  echo "ERROR: cannot inspect source ${src}"
  exit 1
fi

dst_digest="$(digest_of "$dest_ref")"

if [ -n "$dst_digest" ] && [ "$dst_digest" = "$src_digest" ]; then
  echo "SKIP same digest ${src_digest}"
  exit 0
fi

if [ -n "$dst_digest" ] && [ "$dst_digest" != "$src_digest" ]; then
  short="${dst_digest#sha256:}"
  short="${short:0:12}"
  stamp="$(date -u +%Y%m%d-%H%M%S)"
  keep_digest_tag="${repo}:${short}"
  keep_time_tag="${repo}:prev-${dest_tag}-${stamp}"
  echo "KEEP old ${dest_ref} (${dst_digest}) as ${keep_digest_tag} and ${keep_time_tag}"
  skopeo copy --override-os "$OS" --override-arch "$ARCH" \
    "docker://${dest_ref}" "docker://${keep_digest_tag}" || true
  skopeo copy --override-os "$OS" --override-arch "$ARCH" \
    "docker://${dest_ref}" "docker://${keep_time_tag}" || true
fi

skopeo copy --override-os "$OS" --override-arch "$ARCH" \
  "docker://${src}" "docker://${dest_ref}"
echo "OK ${src_digest} -> ${dest_ref}"
