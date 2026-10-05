#!/usr/bin/env sh
# Rebuilds FeedTheGiantCapy.rbxlx from the source files in src/.
set -e
cd "$(dirname "$0")/.."
rojo build default.project.json -o FeedTheGiantCapy.rbxlx
