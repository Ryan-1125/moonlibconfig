#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
work="$root/.local/upstream"
commit=a42cb47c1526a4f2ed025fcbb2289863375bc898
mkdir -p "$work"
curl -fsSL "https://codeload.github.com/hyperrealm/libconfig/tar.gz/$commit" -o "$work/libconfig.tar.gz"
echo "85298e5676bfe9eb0e5dab833b79e5963f903d20a44d1bc76d968aee909a261b  $work/libconfig.tar.gz" | sha256sum --check
tar -xzf "$work/libconfig.tar.gz" -C "$work"
lib="$work/libconfig-$commit/lib"
cc -std=c11 -D_GNU_SOURCE -DLIBCONFIG_STATIC -I"$lib" "$root/tools/oracle.c" \
  "$lib/grammar.c" "$lib/libconfig.c" "$lib/scanctx.c" "$lib/scanner.c" \
  "$lib/strbuf.c" "$lib/strvec.c" "$lib/util.c" "$lib/wincompat.c" -lm -o "$work/oracle"
