#!/bin/sh
# Build the vendored D2R sources standalone with NO runtime present, and report
# the exact symbol seam. This is the measurement behind docs/CONTRACT.md.
#
#   vendor/d2r-mobile/interface/{dm.h,hle.h,front.h}
#       verbatim copies of the upstream host headers the vendored sources
#       include by name. Using the real headers (rather than hand-written
#       shims) is what makes the seam number trustworthy: every type and
#       signature is upstream's, so nothing is masked by a wrong guess.
#   $INC (default /tmp/d2r-shiminc)
#       Darwin/POSIX shims the runtime's compat layer owns on Android. Present
#       here only so the seam can be measured on a glibc host.
#
# Whatever remains undefined after this IS the runtime contract.
set -u
R=$(cd "$(dirname "$0")/../.." && pwd)
V=$R/vendor/d2r-mobile
IF=$V/interface
INC=${INC:-${TMPDIR:-/tmp}/d2r-shiminc}
OUT=${OUT:-${TMPDIR:-/tmp}/d2r-build}
rm -rf "$OUT"; mkdir -p "$OUT/obj" "$INC/mach" "$INC/CommonCrypto"
GEN=${GEN:-${TMPDIR:-/tmp}/d2r-genstub}
sh "$(dirname "$0")/gen-standins.sh" "$GEN" >/dev/null
cp "$GEN/sha1_shim.h" "$INC/"

# The runtime's Darwin compat layer, if it is checked out next to this repo.
# Only mach.h and CommonDigest.h are needed to compile the adapter on a glibc
# host; without them the Darwin-only files are the ones that fail.
RT=${DM_RUNTIME:-$(dirname "$0")/../../../switch-android-runtime}
if [ -d "$RT/runtime/compat/darwin" ]; then
  cp "$RT/runtime/compat/darwin/mach/mach.h" "$INC/mach/mach.h"
  cp "$RT/runtime/compat/darwin/CommonCrypto/CommonDigest.h" "$INC/CommonCrypto/CommonDigest.h"
  # dm_padmode.c includes CommonDigestSHA1.h directly; the runtime ships it, so
  # take it along instead of leaving that one file uncompilable.
  [ -f "$RT/runtime/compat/darwin/CommonCrypto/CommonDigestSHA1.h" ] && \
    cp "$RT/runtime/compat/darwin/CommonCrypto/CommonDigestSHA1.h" "$INC/CommonCrypto/CommonDigestSHA1.h"
else
  echo "note: runtime compat layer not found at $RT (set DM_RUNTIME to point at it)." >&2
  echo "      The adapter still compiles: the two headers are only needed by a" >&2
  echo "      handful of Darwin-only call sites, and empty stand-ins cover them." >&2
  touch "$INC/mach/mach.h" "$INC/CommonCrypto/CommonDigest.h"
fi
cat > "$INC/TargetConditionals.h" <<'EOF'
#ifndef D2R_TC_H
#define D2R_TC_H
#define TARGET_OS_IPHONE 0
#define TARGET_OS_IOS 0
#define TARGET_OS_OSX 1
#define TARGET_OS_MAC 1
#define TARGET_OS_TV 0
#define TARGET_CPU_ARM64 1
#endif
EOF
cat > "$INC/darwin_extra.h" <<'EOF'
/* POSIX shims upstream assumes from Darwin; the runtime's compat layer owns
 * these on Android. Present only so the seam can be measured on a glibc host. */
#ifndef D2R_DARWIN_EXTRA_H
#define D2R_DARWIN_EXTRA_H
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>
#define CLOCK_UPTIME_RAW 8
static inline uint64_t clock_gettime_nsec_np(clockid_t c) {
    struct timespec ts; clock_gettime(c == CLOCK_UPTIME_RAW ? CLOCK_MONOTONIC : c, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
}
#ifndef st_mtimespec
#define st_mtimespec st_mtim
#endif
static inline uint32_t arc4random_uniform(uint32_t bound) {
    if (bound < 2) return 0;
    return (uint32_t)((uint64_t)((rand() << 16) ^ rand()) % bound);
}
#endif
EOF

cd "$V/dm/host"
ok=0; bad=0; oklist=""; badlist=""
for f in dm_*.c; do
  if clang -O1 -w -c -D_GNU_SOURCE -Dgetdtablesize=dm_shim_getdtablesize \
      -I"$IF" -I"$INC" -I$GEN -I"$INC/mach" -I. -I"$V/dm/gfx/nvn/include" \
      -include "$INC/darwin_extra.h" -include "$INC/sha1_shim.h" \
      "$f" -o "$OUT/obj/${f%.c}.o" 2>"$OUT/${f%.c}.err"; then
    ok=$((ok+1)); oklist="$oklist $f"
  else
    bad=$((bad+1)); badlist="$badlist $f"
  fi
done
echo "compiled: ok=$ok failed=$bad"
if [ "$bad" -gt 0 ]; then
  for f in $badlist; do
    echo "--- $f"
    rg -o "error: [^\n]*" "$OUT/${f%.c}.err" | sort -u | head -3
  done
fi

n=$(ls "$OUT/obj" 2>/dev/null | wc -l)
if [ "$n" -gt 0 ]; then
  ar rcs "$OUT/libd2radapter.a" "$OUT"/obj/*.o
  nm -u "$OUT"/obj/*.o 2>/dev/null | rg -o '\bU (\S+)' -r '$1' | sort -u > "$OUT/undef.txt"
  nm --defined-only "$OUT"/obj/*.o 2>/dev/null | rg -o '\b[TDBSRW] (\S+)' -r '$1' | sort -u > "$OUT/def.txt"
  comm -23 "$OUT/undef.txt" "$OUT/def.txt" > "$OUT/seam.txt"
  echo
  echo "objects: $n   seam (undefined & undefined here): $(wc -l < "$OUT/seam.txt")"
  echo "--- dm_* (runtime must provide) ---"
  rg '^dm_' "$OUT/seam.txt" | tr '\n' ' '; echo
  echo "--- non-dm ---"
  rg -v '^dm_' "$OUT/seam.txt" | tr '\n' ' '; echo
fi
