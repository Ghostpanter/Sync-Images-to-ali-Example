#!/usr/bin/env bash
# Local trigger. No server, no image build, no register.
#   export GH_TOKEN=ghp_xxx   # repo + workflow scope
#   ./scripts/client.sh -i image.txt
#   ./scripts/client.sh              # only dispatch, use repo image.txt
set -euo pipefail

REPO="${SYNC_REPO:-Ghostpanter/Sync-Images-to-ali-Example}"
BRANCH="${SYNC_BRANCH:-main}"
WORKFLOW="${SYNC_WORKFLOW:-learn-github-actions.yml}"
LIST=""
UPLOAD=1

usage() {
  cat <<EOF
Usage: $0 [-i image.txt] [--no-upload]

  -i FILE       local image list (same format as repo image.txt)
  --no-upload   do not write FILE to GitHub, only start Action
  env GH_TOKEN  or GITHUB_TOKEN required
  env SYNC_REPO override owner/repo
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -i|--images) LIST="${2:-}"; shift 2 ;;
    --no-upload) UPLOAD=0; shift ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "install GitHub CLI: https://cli.github.com/"
  exit 1
fi
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[ -n "$TOKEN" ] || { echo "set GH_TOKEN"; exit 1; }
export GH_TOKEN="$TOKEN"

if [ -n "$LIST" ] && [ "$UPLOAD" = 1 ]; then
  [ -f "$LIST" ] || { echo "missing $LIST"; exit 1; }
  sha="$(gh api "repos/${REPO}/contents/image.txt?ref=${BRANCH}" --jq .sha 2>/dev/null || true)"
  content="$(base64 -w0 "$LIST" 2>/dev/null || base64 "$LIST" | tr -d '\n')"
  args=(-f message="client: update image.txt" -f content="$content" -f branch="$BRANCH")
  [ -n "$sha" ] && args+=(-f sha="$sha")
  gh api --method PUT "repos/${REPO}/contents/image.txt" "${args[@]}" >/dev/null
  echo "uploaded $LIST -> ${REPO}@${BRANCH}:image.txt"
  echo "push already triggers Action; skip extra dispatch"
  echo "https://github.com/${REPO}/actions"
  exit 0
fi

gh workflow run "$WORKFLOW" --repo "$REPO" --ref "$BRANCH"
echo "dispatched $WORKFLOW on $REPO@$BRANCH"
echo "https://github.com/${REPO}/actions"
