#!/usr/bin/env bash
# TG-7: run both parsers over parser-fixtures/ and fail on any disagreement.
# Requires Node 20+ and a Swift 6 toolchain (Xcode 16+ on macOS).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/reports"
mkdir -p "$OUT"

echo "▸ TypeScript parser"
(cd "$ROOT/extension" && npx --no-install tsx scripts/parser-report.ts --json) > "$OUT/ts.json"

echo "▸ Swift parser"
swift run --package-path "$ROOT/ios/Packages/TrialGuardCore" -c release tgparse "$ROOT/parser-fixtures" > "$OUT/swift.json"

echo "▸ Comparing"
node "$ROOT/scripts/parity-compare.mjs" "$OUT/ts.json" "$OUT/swift.json" "$ROOT/parity-report.md"
