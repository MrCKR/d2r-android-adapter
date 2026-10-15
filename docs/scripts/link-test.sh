#!/bin/sh
# Link the adapter against the stub runtime.
#
# build-adapter.sh proves the adapter COMPILES with no runtime. This proves the
# contract is COMPLETE: every symbol the adapter references is provided by
# docs/scripts/stub-runtime.c and nothing else, so docs/CONTRACT.md neither
# omits a symbol nor overstates one.
#
# --whole-archive is required: without it the linker pulls only the members
# something immediately needs and most of the contract stays unexercised.
set -u
R=$(cd "$(dirname "$0")/../.." && pwd)
OBJ=${OUT:-${TMPDIR:-/tmp}/d2r-build}
STUB="$R/docs/scripts/stub-runtime.c"
CC=${CC:-clang}

if [ ! -f "$OBJ/libd2radapter.a" ]; then
  echo "no adapter archive at $OBJ — run build-adapter.sh first" >&2
  exit 2
fi

cat > "$OBJ/linkmain.c" <<'EOF'
#include <stdint.h>
extern uint32_t dm_cur_tick(void);
extern void dm_padmode_boot(void);
extern uint64_t dm_server_tick(void);
extern void dm_bright_server_tick(uint64_t g);
extern void dm_freetp_server_step(uint8_t *base, uint64_t g, uint64_t player);
int main(void) { volatile uint32_t t = dm_cur_tick(); (void)t; return 0; }
EOF

$CC -c -O1 -o "$OBJ/linkmain.o" "$OBJ/linkmain.c"

echo "linking adapter archive + stub runtime"
if $CC -O1 -o "$OBJ/linktest" "$OBJ/linkmain.o" \
      -Wl,--whole-archive "$OBJ/libd2radapter.a" -Wl,--no-whole-archive \
      "$STUB" -lpthread -lm 2>"$OBJ/link.err"; then
  echo "LINK OK — the contract in docs/CONTRACT.md is complete"
  echo "binary: $(wc -c < "$OBJ/linktest") bytes"
  exit 0
fi

echo "LINK FAILED — the contract is missing something:"
rg -o "undefined (symbol|reference) to [^\n]*" "$OBJ/link.err" | sort -u
exit 1
