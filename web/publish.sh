#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Leo Kuroshita (@kurogedelic), Hügelton Instruments
# Publish the web site (GitHub Pages, gh-pages branch):
#
#   web/publish.sh [VERSION]     # default: dev
#
# Makes the site from the package in build/felucca.fwsc with web/make_site.py, then commits it to
# the gh-pages branch with the index plumbing (a temp index, write-tree / commit-tree: no worktree,
# the branch's checkout never exists) and pushes it. The fetched remote head is the parent, so every
# publish fast-forwards what is on the server.
# Enable Pages once in the GitHub UI: Settings > Pages > Deploy from a branch: gh-pages, / (root).
set -e
VER="${1:-dev}"
cd "$(dirname "$0")/.."
[ -f build/felucca.fwsc ] || { echo "publish: run ./build.sh first (build/felucca.fwsc)"; exit 1; }

SITE=$(mktemp -d "${TMPDIR:-/tmp}/felucca-site.XXXXXX") || exit 1
INDEX=$(mktemp "${TMPDIR:-/tmp}/felucca-index.XXXXXX") || exit 1
trap 'rm -rf "$SITE" "$INDEX"' EXIT
python3 web/make_site.py build/felucca.fwsc "$VER" "$SITE"
: > "$SITE/.nojekyll"

PARENT=""
if git fetch -q origin gh-pages 2>/dev/null; then
    PARENT=$(git rev-parse -q --verify refs/remotes/origin/gh-pages) || PARENT=""
fi

export GIT_INDEX_FILE="$INDEX"
git read-tree --empty
find "$SITE" -type f | while IFS= read -r f; do
    git update-index --add --cacheinfo "100644,$(git hash-object -w "$f"),${f#"$SITE"/}"
done
TREE=$(git write-tree)
unset GIT_INDEX_FILE
if [ -n "$PARENT" ]; then
    COMMIT=$(echo "site: felucca-$VER" | git commit-tree "$TREE" -p "$PARENT")
else
    COMMIT=$(echo "site: felucca-$VER" | git commit-tree "$TREE")
fi
if git push -q origin "$COMMIT:refs/heads/gh-pages"; then
    echo "publish: pushed gh-pages: $COMMIT (felucca-$VER)"
fi
