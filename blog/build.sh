#!/usr/bin/env bash
#
# Build a blog post from Markdown into a site-matching HTML page.
#
# Usage:
#   ./blog/build.sh blog/_posts/my-post.md      # build one post
#   ./blog/build.sh                             # build every post in blog/_posts/
#
# The output file is named after the Markdown file (my-post.md -> my-post.html)
# and written next to the other blog pages in blog/. The slug used for the
# canonical URL is derived from that filename, so name your .md file exactly
# what you want the URL to be.

set -euo pipefail

# Run from the repo root no matter where the script is called from.
cd "$(dirname "$0")/.."

build_one() {
  local src="$1"
  local slug
  slug="$(basename "${src%.md}")"
  local out="blog/${slug}.html"

  pandoc "$src" \
    --from markdown \
    --to html5 \
    --template blog/_template.html \
    --syntax-highlighting=none \
    --wrap=preserve \
    --metadata slug="$slug" \
    --output "$out"

  echo "Built $out"
}

if [ "$#" -ge 1 ]; then
  build_one "$1"
else
  for f in blog/_posts/*.md; do
    build_one "$f"
  done
fi
