#!/usr/bin/env bash
# Example:
#   nginx:latest  already on ACR as digest of 1.21
#   source latest now points to 1.22
# Result on ACR:
#   kkun/nginx:latest  -> 1.22
#   kkun/nginx:1.22    -> 1.22
#   kkun/nginx:1.21    -> previous latest (kept)
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
[ -z "$dest_name" ] && dest_name="${src##*/}"

if [[ "$dest_name" == *:* ]]; then
  dest_repo_name="${dest_name%:*}"
  dest_tag="${dest_name##*:}"
else
  dest_repo_name="$dest_name"
  dest_tag="latest"
fi

repo="${ACR_REGISTRY}/${ACR_NAMESPACE}/${dest_repo_name}"
dest_ref="${repo}:${dest_tag}"

echo "==== ${src} -> ${dest_ref} (${OS}/${ARCH}) ===="

inspect_json() {
  skopeo inspect --override-os "$OS" --override-arch "$ARCH" "docker://${1}" 2>/dev/null || true
}

digest_from_json() {
  echo "$1" | jq -r '.Digest // empty'
}

version_from_ref() {
  local ref="$1"
  local t="${ref##*:}"
  [[ "$ref" != *:* ]] && { echo ""; return; }
  case "$t" in
    latest|stable|main|master|dev|nightly|edge) echo "" ;;
    *) echo "$t" ;;
  esac
}

version_from_json() {
  local json="$1"
  echo "$json" | jq -r '
    .Labels["org.opencontainers.image.version"]
    // .Labels.version
    // .Labels.VERSION
    // .Labels["nginx.version"]
    // empty
  ' | sed 's/^v//' 
}

copy_img() {
  skopeo copy --override-os "$OS" --override-arch "$ARCH" "docker://${1}" "docker://${2}"
}

src_json="$(inspect_json "$src")"
[ -z "$src_json" ] && { echo "ERROR: cannot inspect source ${src}"; exit 1; }
src_digest="$(digest_from_json "$src_json")"
[ -z "$src_digest" ] && { echo "ERROR: empty source digest"; exit 1; }

new_ver="$(version_from_ref "$src")"
[ -z "$new_ver" ] && new_ver="$(version_from_json "$src_json")"
# drop debian suffix noise like 1.27.3-bookworm -> keep full tag if from ref; labels often clean

dst_json="$(inspect_json "$dest_ref")"
dst_digest="$(digest_from_json "$dst_json")"

if [ -n "$dst_digest" ] && [ "$dst_digest" = "$src_digest" ]; then
  echo "SKIP same digest ${src_digest}"
  if [ -n "$new_ver" ] && [ "$new_ver" != "$dest_tag" ]; then
    if [ "$(digest_from_json "$(inspect_json "${repo}:${new_ver}")")" != "$src_digest" ]; then
      echo "TAG ${dest_ref} also as ${repo}:${new_ver}"
      copy_img "$dest_ref" "${repo}:${new_ver}" || true
    fi
  fi
  exit 0
fi

if [ -n "$dst_digest" ] && [ "$dst_digest" != "$src_digest" ]; then
  old_ver="$(version_from_json "$dst_json")"
  [ -z "$old_ver" ] && old_ver="$(version_from_ref "$dest_ref")"
  if [ -z "$old_ver" ] || [ "$old_ver" = "$dest_tag" ] || [ "$old_ver" = "latest" ]; then
    short="${dst_digest#sha256:}"
    old_ver="prev-${dest_tag}-${short:0:12}"
  fi
  echo "KEEP old ${dest_ref} (${dst_digest}) as ${repo}:${old_ver}"
  copy_img "$dest_ref" "${repo}:${old_ver}" || true
fi

copy_img "$src" "$dest_ref"
echo "OK ${src_digest} -> ${dest_ref}"

if [ -n "$new_ver" ] && [ "$new_ver" != "$dest_tag" ]; then
  echo "TAG new image also as ${repo}:${new_ver}"
  copy_img "$dest_ref" "${repo}:${new_ver}" || true
fi
