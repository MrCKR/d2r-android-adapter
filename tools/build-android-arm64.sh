#!/bin/sh
# Cross-compile the D2R adapter for Android/arm64.
#
# Direction of the dependency is adapter -> runtime: this script includes the
# runtime's host headers and Darwin compat layer, and produces an archive whose
# undefined symbols ARE the runtime contract (see docs/CONTRACT.md).  The
# runtime is never asked to compile anything from here.
#
#   DM_RUNTIME   path to a switch-android-runtime checkout  (required)
#   ANDROID_SDK_ROOT / ANDROID_HOME, or SDK   SDK location  (default below)
#   OUT          output directory           (default build/android-arm64)
#
# Output: $OUT/libd2r_adapter.a  plus $OUT/seam.txt listing the symbols the
# runtime must supply.  Packaging adds the archive at link time; while it is
# absent the runtime links its own inert seam instead.
set -eu
R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SDK=${SDK:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/var/minis/workspace/android-sdk}}}
RT=${DM_RUNTIME:-}
OUT=${OUT:-$R/build/android-arm64}

[ -n "$RT" ] || { echo "DM_RUNTIME must point at a switch-android-runtime checkout" >&2; exit 2; }
[ -d "$RT/runtime/host" ] || { echo "no runtime/host under $RT" >&2; exit 2; }

NDK=$(ls -d "$SDK"/ndk/* 2>/dev/null | tail -1)
[ -n "$NDK" ] || { echo "no NDK under $SDK" >&2; exit 2; }
PRE="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
SYS="$PRE/sysroot"
[ -d "$SYS" ] || { echo "no sysroot under $NDK" >&2; exit 2; }

V="$R/vendor/d2r-mobile"
SRC="$V/dm/host"
INC="$OUT/include"

rm -rf "$OUT"; mkdir -p "$OUT/obj" "$INC/CommonCrypto" "$INC/mach"

# --- headers ---------------------------------------------------------------
# The upstream interface headers are vendored verbatim; the Darwin/POSIX shims
# come from the runtime's compat layer (the adapter does not own them).
for h in "$V"/interface/dm.h "$V"/interface/hle.h "$V"/interface/front.h; do
  [ -f "$h" ] && cp "$h" "$INC/" || true
done
for h in mach/mach.h CommonCrypto/CommonDigest.h CommonCrypto/CommonDigestSHA1.h; do
  src="$RT/runtime/compat/darwin/$h"
  [ -f "$src" ] && cp "$src" "$INC/$h" || touch "$INC/$h"
done

# --- generated headers -----------------------------------------------------
# dm_bright.c / dm_vault_ui.c / diag.c include headers derived from the USER'S
# game files.  They are build inputs of this adapter, never of the runtime, and
# they are never committed (data boundary).  Point DM_GENERATED at a directory
# holding them, or let the stand-ins below supply compilable placeholders.
GEN=${DM_GENERATED:-}
( cd "$R" && sh docs/scripts/gen-standins.sh "$OUT/genstub" >/dev/null 2>&1 ) || true
GENINC="$OUT/genstub"
[ -n "$GEN" ] && GENINC="$GEN:$GENINC"
IFLAGS=""
OLDIFS=$IFS; IFS=:
for d in $GENINC; do [ -n "$d" ] && IFLAGS="$IFLAGS -I$d"; done
IFS=$OLDIFS

TGT="--target=aarch64-linux-android29 --sysroot=$SYS"
COMPAT="$RT/runtime/compat"
CFLAGS="$TGT -fPIC -std=gnu11 -fno-stack-protector -fblocks \
 -I$INC -I$COMPAT/darwin -I$COMPAT -I$RT/runtime/host -I$RT/runtime/tls $IFLAGS \
 -include $COMPAT/darwin/platform_compat.h"

CLANG=$PRE/bin/clang
[ -x "$CLANG" ] || CLANG=clang

ok=0; fail=0; failed=""
for src in "$SRC"/dm_*.c; do
  name=$(basename "$src" .c)
  if $CLANG $CFLAGS -c "$src" -o "$OUT/obj/$name.o" 2>"$OUT/obj/$name.err"; then
    ok=$((ok+1))
  else
    fail=$((fail+1)); failed="$failed $name"
  fi
done
echo "adapter android-arm64: compiled ok=$ok failed=$fail"
[ -n "$failed" ] && { echo "failed:$failed"; for n in $failed; do echo "--- $n"; tail -3 "$OUT/obj/$n.err"; done; }

# llvm-ar from the NDK is an x86_64 binary and cannot run on an arm64 host, so
# use the system archiver; the archive format is the same.
ar rcs "$OUT/libd2r_adapter.a" "$OUT"/obj/*.o

# The undefined symbols of the archive are exactly what the runtime must expose.
nm -u "$OUT/libd2r_adapter.a" 2>/dev/null | sed 's/^ *U //' | sort -u > "$OUT/seam.raw.txt" || true
echo "seam symbols: $(wc -l < "$OUT/seam.raw.txt")"
echo "$OUT/libd2r_adapter.a"
