#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Runs the project in headless mode. The project is configured to use
# res://tests/TestBootstrap.tscn as the main scene (a smoke/CI test).
exec godot --headless --path "$ROOT_DIR" "$@"
