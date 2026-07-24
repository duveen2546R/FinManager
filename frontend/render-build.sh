#!/usr/bin/env bash
# Render Static Sites do not include Flutter by default. This installs the
# stable SDK in Render's ephemeral build environment and outputs build/web.
set -euo pipefail

render_flutter_dir="$HOME/flutter"
# ionicons 0.2.2 builds with the Flutter SDK used locally (3.38.5), while
# Flutter 3.44 makes IconData non-extendable and breaks that package.
render_flutter_version="${FLUTTER_VERSION:-3.38.5}"
git clone --depth 1 --branch "$render_flutter_version" https://github.com/flutter/flutter.git "$render_flutter_dir"
"$render_flutter_dir/bin/flutter" config --enable-web
"$render_flutter_dir/bin/flutter" pub get
"$render_flutter_dir/bin/flutter" build web --release
