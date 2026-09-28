#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
exec "${ABRAMS_PYTHON:-python3}" "$ROOT/tools/package_runtime.py" "$@"
