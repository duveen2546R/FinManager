/**
 * Expo config plugin: fix the `fmt` library for Xcode 16/26.
 *
 * Xcode 16+ ships a Clang that strictly enforces C++20 `consteval`, which the
 * older `fmt` library pinned by React Native 0.76 (Expo SDK 52) violates via
 * FMT_STRING. Without this, `pod` target `fmt » format.cc` fails to compile.
 *
 * `fmt` gates consteval behind the FMT_USE_CONSTEVAL macro, which its header
 * (`fmt/base.h`) defines unconditionally — so a compiler `-D` flag can't win.
 * This plugin injects a Podfile `post_install` step that rewrites that macro to
 * `0` in the header on every `pod install`, making fmt's compile-time string
 * checks plain (non-consteval) functions that compile cleanly.
 *
 * Because this lives in the tracked config (not the generated `ios/` folder),
 * `npx expo prebuild` reproduces the fix automatically on a fresh checkout.
 */
const { withDangerousMod } = require('expo/config-plugins');
const fs = require('fs');
const path = require('path');

const MARKER = '# [withFmtConstevalFix]';

const PATCH_SNIPPET = `
    ${MARKER} Force fmt's FMT_USE_CONSTEVAL to 0 so it builds under Xcode 16/26 Clang.
    fmt_base = File.join(__dir__, 'Pods', 'fmt', 'include', 'fmt', 'base.h')
    if File.exist?(fmt_base)
      contents = File.read(fmt_base)
      patched = contents.gsub('#  define FMT_USE_CONSTEVAL 1', '#  define FMT_USE_CONSTEVAL 0')
      File.write(fmt_base, patched) if patched != contents
    end
`;

module.exports = function withFmtConstevalFix(config) {
  return withDangerousMod(config, [
    'ios',
    (cfg) => {
      const podfilePath = path.join(cfg.modRequest.platformProjectRoot, 'Podfile');
      let podfile = fs.readFileSync(podfilePath, 'utf8');

      if (!podfile.includes(MARKER)) {
        // Inject at the top of the existing `post_install do |installer|` block.
        podfile = podfile.replace(
          /post_install do \|installer\|/,
          `post_install do |installer|${PATCH_SNIPPET}`,
        );
        fs.writeFileSync(podfilePath, podfile);
      }
      return cfg;
    },
  ]);
};
