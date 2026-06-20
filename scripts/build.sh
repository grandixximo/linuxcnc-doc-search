#!/bin/sh
# Add pagefind search to an extracted LinuxCNC HTML docs tree.
#   scripts/build.sh [HTML_DIR]   (default: html)
# Steps: inject the search box + stylesheet (and mark the topbar chrome so it
# is not indexed), then build one isolated pagefind index per language subtree.
set -eu

HTML=${1:-html}
PAGEFIND_VERSION=${PAGEFIND_VERSION:-v1.5.2}
# sha256 of pagefind-$PAGEFIND_VERSION-x86_64-unknown-linux-musl.tar.gz; bump
# both together when upgrading.
PAGEFIND_SHA256=${PAGEFIND_SHA256:-afb824a9e7f64905a934900481cea5be679c03975e527329e0e5e6cc70f5feda}
HERE=$(CDPATH= cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")

# pagefind binary: use one on PATH (e.g. installed on the host), else fetch the
# pinned release into a temp dir and verify its sha256 before use.  The download
# only ever happens on an ephemeral CI runner; the production server is expected
# to serve the static output, never to run this.
if command -v pagefind >/dev/null 2>&1; then
  PAGEFIND=pagefind
else
  tmp=$(mktemp -d)
  curl --no-progress-meter -fL \
    "https://github.com/Pagefind/pagefind/releases/download/$PAGEFIND_VERSION/pagefind-$PAGEFIND_VERSION-x86_64-unknown-linux-musl.tar.gz" \
    -o "$tmp/pagefind.tar.gz"
  echo "$PAGEFIND_SHA256  $tmp/pagefind.tar.gz" | sha256sum -c -
  tar -xzf "$tmp/pagefind.tar.gz" -C "$tmp"
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
