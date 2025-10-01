#!/usr/bin/env bash
set -euo pipefail

# Runs GdUnit4 tests via runtest.sh.
# GODOT_BINARY env var must be set.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

# Validate GODOT_BINARY env var
if [[ -z "${GODOT_BINARY:-}" ]]; then
  echo "Error: GODOT_BINARY environment variable is not set." >&2
  echo "Set it to your Godot binary path, e.g.:" >&2
  echo "  export GODOT_BINARY=/Applications/Godot.app/Contents/MacOS/Godot" >&2
  exit 1
fi

# Ensure binary exists and is executable
BINARY_PATH="${GODOT_BINARY/#\~/$HOME}" # Expand leading ~ if present
if [[ ! -x "$BINARY_PATH" ]]; then
  if [[ -f "$BINARY_PATH" ]]; then
    echo "Error: Godot binary exists but is not executable: $BINARY_PATH" >&2
  else
    echo "Error: Godot binary not found or not accessible: $BINARY_PATH" >&2
  fi
  exit 1
fi

# Run tests
cd "$TESTS_DIR"
# Not using runtest.sh because it runs Godot in debug mode,
# which stays in an interactive shell upon hitting an error.
# We want to fail in that case. 
"$BINARY_PATH" --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue