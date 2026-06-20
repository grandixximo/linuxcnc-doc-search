#!/bin/sh
# Add pagefind search to an extracted LinuxCNC HTML docs tree.
#   scripts/build.sh [HTML_DIR]   (default: html)
# Steps: inject the search box + stylesheet (and mark the topbar chrome so it
# is not indexed), then build one isolated pagefind index per language subtree.
set -eu

HTML=${1:-html}
PAGEFIND_VERSION=${PAGEFIND_VERSION:-v1.5.2}
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")

# pagefind binary: use one on PATH, else fetch the pinned release into a temp
# dir (nothing is left in the tree).
if command -v pagefind >/dev/null 2>&1; then
  PAGEFIND=pagefind
else
  tmp=$(mktemp -d)
  curl --no-progress-meter -fL \
    "https://github.com/Pagefind/pagefind/releases/download/$PAGEFIND_VERSION/pagefind-$PAGEFIND_VERSION-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$tmp"
  PAGEFIND="$tmp/pagefind"
fi

# 1. inject search box + stylesheet link, mark chrome (must precede indexing)
python3 "$HERE/inject.py" "$HTML"

# 2. one isolated index per language subtree, so results stay in one language
for d in "$HTML"/*/; do
  lang=$(basename "$d")
  [ "$lang" = "_pagefind" ] && continue
  [ -n "$(find "$d" -name '*.html' -print -quit 2>/dev/null)" ] || continue
  rm -rf "$d/_pagefind"
  "$PAGEFIND" --site "$d" --output-subdir _pagefind
done

# 3. stylesheet at the html root
cp "$ROOT/assets/search.css" "$HTML/search.css"

echo "search build complete in $HTML"
