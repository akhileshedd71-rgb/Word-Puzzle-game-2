#!/usr/bin/env bash
# Build installable test APKs and browser previews using Godot's official templates.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:-all}"
output_dir="${2:-$project_dir/builds}"
godot_bin="${GODOT_BIN:-godot}"
case "$target" in web|android|all) ;; *) echo "Usage: $0 [web|android|all] [output-directory]" >&2; exit 2;; esac
command -v "$godot_bin" >/dev/null || { echo 'Install Godot 4.6.3 (standard edition) first.' >&2; exit 1; }
[[ "$("$godot_bin" --version)" == 4.6.3.* ]] || { echo 'Use Godot 4.6.3 with matching 4.6.3 export templates.' >&2; exit 1; }
mkdir -p "$output_dir"
output_dir="$(cd -- "$output_dir" && pwd)"
touch "$output_dir/.gdignore"

# Import before export so fresh checkouts have fonts, SVGs, and script class metadata.
"$godot_bin" --headless --path "$project_dir" --editor --import

if [[ "$target" == web || "$target" == all ]]; then
  mkdir -p "$output_dir/web"
  "$godot_bin" --headless --path "$project_dir" --export-release Web "$output_dir/web/index.html"
  echo "Web export: $output_dir/web/index.html (serve this directory over HTTP)"
fi

if [[ "$target" == android || "$target" == all ]]; then
  sdk_path="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  [[ -d "$sdk_path/build-tools" ]] || { echo 'Set ANDROID_HOME to an Android SDK with build-tools 36.0.0 and platform-tools.' >&2; exit 1; }
  java_path="${JAVA_HOME:-}"
  if [[ -z "$java_path" ]]; then
    java_path="$(dirname -- "$(dirname -- "$(readlink -f -- "$(command -v java)")")")"
  fi
  [[ -x "$java_path/bin/keytool" ]] || { echo 'Set JAVA_HOME to OpenJDK 17 or newer.' >&2; exit 1; }

  # Test-only signing identity; never use this key to publish to an app store.
  # Preserve this local file across builds to allow APK updates without losing saves.
  signing_dir="${FOLIO_SIGNING_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/folio/signing}"
  mkdir -p "$signing_dir"
  debug_key="$signing_dir/debug.keystore"
  if [[ ! -f "$debug_key" ]]; then
    "$java_path/bin/keytool" -genkeypair -noprompt -keystore "$debug_key" \
      -storepass android -keypass android -alias androiddebugkey \
      -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
  fi

  # Isolated editor settings keep machine paths and signing configuration out of Git.
  # XDG_DATA_HOME is intentionally retained so Godot finds installed export templates.
  settings_dir="$(mktemp -d)"
  trap 'rm -rf -- "$settings_dir"' EXIT
  mkdir -p "$settings_dir/godot"
  python3 - "$settings_dir/godot/editor_settings-4.6.tres" "$sdk_path" "$java_path" "$debug_key" <<'PY'
import json, pathlib, sys
path, sdk, java, key = sys.argv[1:]
settings = {
    'export/android/android_sdk_path': str(pathlib.Path(sdk).resolve()),
    'export/android/java_sdk_path': str(pathlib.Path(java).resolve()),
    'export/android/debug_keystore': str(pathlib.Path(key).resolve()),
    'export/android/debug_keystore_user': 'androiddebugkey',
    'export/android/debug_keystore_pass': 'android',
}
pathlib.Path(path).write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' + ''.join(f'{k} = {json.dumps(v)}\n' for k, v in settings.items()))
PY
  mkdir -p "$output_dir/android"
  XDG_CONFIG_HOME="$settings_dir" "$godot_bin" --headless --path "$project_dir" \
    --export-debug Android "$output_dir/android/Folio-debug.apk"
  signer="$sdk_path/build-tools/36.0.0/apksigner"
  [[ ! -x "$signer" ]] || JAVA_HOME="$java_path" "$signer" verify "$output_dir/android/Folio-debug.apk"
  echo "Android test APK: $output_dir/android/Folio-debug.apk"
fi
