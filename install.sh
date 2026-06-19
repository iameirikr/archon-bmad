#!/usr/bin/env bash
#
# Install the bmad-implement workflow into Archon.
#
#   ./install.sh                       # -> $ARCHON_HOME/workflows (default ~/.archon/workflows), global
#   ./install.sh /path/to/repo/.archon/workflows   # -> a specific project
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/workflows/bmad-implement.yaml"

if [ ! -f "$SRC" ]; then
  echo "ERROR: $SRC not found." >&2
  exit 1
fi

DEFAULT_DEST="${ARCHON_HOME:-$HOME/.archon}/workflows"
DEST="${1:-$DEFAULT_DEST}"

mkdir -p "$DEST"
cp "$SRC" "$DEST/"

echo "Installed bmad-implement -> $DEST/bmad-implement.yaml"
echo
echo "Verify:   archon workflow list | grep bmad-implement"
echo "Run:      archon workflow run bmad-implement \"epic 2\""
