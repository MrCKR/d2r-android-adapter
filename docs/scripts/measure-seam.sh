#!/bin/sh
# Can the D2R feature modules be lifted out of dm/host as a self-contained unit,
# TODAY, with no runtime and no game files?
#   - compile each dm_*.c against the runtime's Darwin compat layer
#   - archive the objects into libd2radapter.a (no link resolution needed)
#   - report the exact undefined-symbol seam the archive would require from the host
set -u
D=${DM_UPSTREAM:-vendor/d2r-mobile}
COMPAT=${DM_RUNTIME:-../switch-android-runtime/runtime/compat}
INC=/tmp/stubinc
OUT=${OUT:-/tmp/d2r-seam}
rm -rf "$OUT"; mkdir -p "$OUT/obj"
mkdir -p "$INC/mach" "$INC/CommonCrypto"
cp "$COMPAT/darwin/mach/mach.h" "$INC/mach/mach.h"
cp "$COMPAT/darwin/CommonCrypto/CommonDigest.h" "$INC/CommonCrypto/CommonDigest.h"
printf '#ifndef TC_H\n#define TC_H\n#define TARGET_OS_IPHONE 0\n#define TARGET_OS_IOS 0\n#define TARGET_OS_OSX 1\n#define TARGET_OS_MAC 1\n#define TARGET_OS_TV 0\n#define TARGET_CPU_ARM64 1\n#endif\n' > "$INC/TargetConditionals.h"

cd "$D/dm/host"
ok=0; bad=0; oklist=""; badlist=""
for f in dm_*.c; do
  if clang -O1 -w -c -D_GNU_SOURCE -Dgetdtablesize=dm_shim_getdtablesize \
      -I"$INC" -I"$COMPAT/darwin" -I"$COMPAT" -I. -I../gfx/nvn/include \
      "$f" -o "$OUT/obj/$(basename "$f" .c).o" 2>"$OUT/$(basename "$f" .c).err"; then
    ok=$((ok+1)); oklist="$oklist $f"
  else
    bad=$((bad+1)); badlist="$badlist $f"
  fi
done
echo "compiled: ok=$ok failed=$bad"
echo "built objects: $(ls "$OUT/obj" | wc -l)"
ar rcs "$OUT/libd2radapter.a" "$OUT"/obj/*.o 2>/dev/null
echo "archive size: $(du -h "$OUT/libd2radapter.a" | cut -f1)"
echo "archive members: $(ar t "$OUT/libd2radapter.a" | wc -l)"

echo
echo "=== undefined symbols the archive needs from the host (the seam) ==="
nm -u "$OUT"/obj/*.o 2>/dev/null | rg -o '^\s+U \S+' | awk '{print $2}' | sort -u > "$OUT/undef.txt"
echo "total undefined: $(wc -l < "$OUT/undef.txt")"
echo "--- dm_* ones (adapter-to-host contract) ---"
rg '^dm_' "$OUT/undef.txt" | wc -l
rg '^dm_' "$OUT/undef.txt" | tr '\n' ' '
echo
echo "--- non-dm ones (libc/HLE surface) ---"
rg -v '^dm_' "$OUT/undef.txt" | wc -l
