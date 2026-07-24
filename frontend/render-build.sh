#!/usr/bin/env bash
# Build with the project-pinned Flutter SDK and output build/web for Render.
set -euo pipefail

# ionicons 0.2.2 builds with the Flutter SDK used locally (3.38.5), while
# Flutter 3.44 makes IconData non-extendable and breaks that package.
render_flutter_version="${FLUTTER_VERSION:-3.38.5}"
# Render's $HOME already contains its own Flutter SDK. Use a unique temporary
# directory so the pinned SDK never collides with that preinstalled copy.
render_flutter_dir="$(mktemp -d /tmp/finmanager-flutter.XXXXXX)"
git clone --depth 1 --branch "$render_flutter_version" https://github.com/flutter/flutter.git "$render_flutter_dir"
"$render_flutter_dir/bin/flutter" config --enable-web
"$render_flutter_dir/bin/flutter" pub get
"$render_flutter_dir/bin/flutter" build web --release
