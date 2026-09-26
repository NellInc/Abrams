#!/bin/sh
cd "$(dirname "$0")" || exit 1
exec ./tools/godot.sh res://scenes/art_review.tscn
