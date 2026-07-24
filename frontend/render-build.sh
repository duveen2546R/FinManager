#!/usr/bin/env bash
# Render Static Sites do not include Flutter by default. This installs the
# stable SDK in Render's ephemeral build environment and outputs build/web.
set -euo pipefail

render_flutter_dir="$HOME/flutter"
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$render_flutter_dir"
"$render_flutter_dir/bin/flutter" config --enable-web
"$render_flutter_dir/bin/flutter" pub get
"$render_flutter_dir/bin/flutter" build web --release
