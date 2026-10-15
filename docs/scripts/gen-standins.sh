#!/bin/sh
# Generate stand-in versions of the three headers that are built from the user's
# own game files and are deliberately absent from the repository:
#   dm_bright_levels.inc, dm_vault_tab.h, and the CC_SHA1 shim.
#
# These stand-ins exist ONLY so the adapter can be compiled and its symbol seam
# measured without the game. They carry dummy data and must never ship. A real
# build generates them from the user's own game files (see
# docs/MIGRATION-1.md, "generated at build time").
set -eu
OUT=${1:-/tmp/d2r-genstub}
mkdir -p "$OUT"

# dm_bright_levels.inc: the initialiser list for k_lv[] in dm_host/dm_bright.c.
# Real generator: dm/tools/gen_bright_levels.py. Shape: {lv, act, drlg, varies},
cat > "$OUT/dm_bright_levels.inc" <<'EOF'
/* STAND-IN — dummy level table, measurement only, never ship.
 * Real content comes from gen_bright_levels.py over the user's own game files. */
EOF
i=0
while [ $i -lt 200 ]; do
  printf '{ %d, %d, %d, %d },\n' "$i" "$((i / 40))" 3 -1 >> "$OUT/dm_bright_levels.inc"
  i=$((i + 1))
done

# dm_vault_tab.h: the wide-stash table. Real generator: dm/ios/tools/gen_vault_table.py
cat > "$OUT/dm_vault_tab.h" <<'EOF'
/* STAND-IN — dummy wide-stash table, measurement only, never ship.
 * Real content comes from gen_vault_table.py over the user's own game files. */
#pragma once
#define VT_NPART 11
static const char *const vt_part_name[VT_NPART] = {
    "Helms", "Body", "Shields", "Gloves", "Boots", "Belts",
    "Rings", "Amulets", "Weapons", "Offhand", "Staves & Casters" };
typedef struct { uint8_t kind, part, tier; uint16_t row, lvl; int16_t set; const char *key, *icon; } vt_row;
static const vt_row vt_rows[] = {
    { 1, 0, 0, 0, 0, -1, "dummy", "dummy" },
    { 0, 1, 0, 1, 0,  0, "dummy", "dummy" },
};
#define VT_NROW (int)(sizeof vt_rows / sizeof vt_rows[0])
static const char *const vt_set_key[] = { "dummy_set" };
#define VT_NSET (int)(sizeof vt_set_key / sizeof vt_set_key[0])
EOF

# CC_SHA1: the runtime's compat layer owns CommonCrypto. Its CommonDigest.h
# currently provides only MD5 and SHA256; dm_padmode.c needs SHA1 as well.
cat > "$OUT/sha1_shim.h" <<'EOF'
/* STAND-IN for the CC_SHA1 the runtime's CommonCrypto shim must add. */
#ifndef D2R_CC_SHA1_SHIM
#define D2R_CC_SHA1_SHIM
#include <stdint.h>
#include <string.h>
#define CC_SHA1_DIGEST_LENGTH 20
typedef uint32_t CC_LONG;
/* Not a real SHA-1: measurement builds only. */
static inline unsigned char *CC_SHA1(const void *d, CC_LONG n, unsigned char *md) {
    const unsigned char *p = (const unsigned char *)d; unsigned h = 2166136261u;
    for (CC_LONG i = 0; i < n; i++) { h ^= p[i]; h *= 16777619u; }
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) { md[i] = (unsigned char)h; h = h * 31u + 7u; }
    return md;
}
#endif
EOF
echo "stand-in headers written to $OUT"
ls -la "$OUT"
