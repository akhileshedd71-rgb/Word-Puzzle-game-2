#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
python3 tools/build_content.py --validate
godot --headless --path . --editor --import
godot --headless --path . --script tests/test_systems.gd
godot --headless --path . --script tests/test_ui.gd
