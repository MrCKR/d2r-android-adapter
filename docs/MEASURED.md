# Measurements

Every number in [`CONTRACT.md`](CONTRACT.md) and [`MIGRATION-1.md`](MIGRATION-1.md)
comes from a command in this file. Reproduce with
`sh docs/scripts/build-adapter.sh`.

## 1. Per-module portability

Upstream `dm/host/dm_*.c` (39 files, 13.8k lines) against the runtime's Darwin
compat layer, on the host toolchain:

```text
compiled: ok=39 failed=0
```

The last three to pass needed stand-ins for headers that are generated from the
user's own game files and are deliberately absent from the repository
(`dm_bright_levels.inc`, `dm_vault_tab.h`) plus a `CC_SHA1` shim. The stand-ins
carry dummy data and never ship:
`docs/scripts/gen-standins.sh`.

**Caveat: this is a glibc host build, not an NDK cross-build.** It measures the
*symbol* seam faithfully (types and signatures are upstream's) but says nothing
about ARM64 codegen or Android availability. Two host-only workarounds are in
play and are not Android issues: `getdtablesize` collides with glibc's
declaration, and `pthread_getattr_np` needs `_GNU_SOURCE`.

## 2. The symbol seam

```sh
nm -u <all .o>                        # undefined
nm --defined-only <same>              # defined in the adapter
comm -23 undefined defined            # 134
```

Of those 134, 84 are libc/compiler-rt on the Android target. The remaining 50:

| Group | Count |
|---|---:|
| runtime host surface | 19 |
| D2R debt in the runtime's `diag.c` | 10 |
| host globals / small delegates | 20 |
| macOS-only | 1 |

## 3. Migration size

| Where | Files | Size |
|---|---:|---:|
| `dm/host/dm_*.c`, `dm_*.h` | 62 | 2.3 MB |
| `dm/gfx/nvn` fact tables + `include/nvn.h` | 31 | 2.9 MB |
| `dm/gfx/tools` shader chain | (in above) | — |
| `dm/i18n` | 5 | 91 KB |
| `dm/tools` | 36 | 355 KB |
| `dm/verify` | 102 | 897 KB |
| `dm/ios/Sources/dm_touch_*` | 12 | 222 KB |
| `dm/data/casc_overlay` | 1 | 11 KB |
| `dm/PRODUCT` + `touchrectv1_patch.json` | 2 | — |
| **total vendored** | **250** | **6.0 MB** |

Left behind and why: see `MIGRATION-1.md`.

## 4. Fact tables carried (not game content)

| File | Size | Content |
|---|---:|---|
| `shader_map.tsv` | 1.33 MB | shader variant IDs and checksums |
| `shader_facts.tsv` | 1.13 MB | per-shader interface description |
| `pso_manifest.tsv` | 177 KB | pipeline state combinations used by the game |
| `nvn_slots.tsv` + `names.txt` | 40 KB | 523 NVN function names and their slots |
| `include/nvn.h` | 89 KB | NVN declarations, third-party MIT |
| `ui_text.tsv` | 56 KB | 372 adapter-authored UI strings |
| `touchrectv1_patch.json` | 28 KB | controller layout description |
| `borrowed_paths.tsv` | 2 KB | 6 reused original texture path names |

## 5. Version pinning

| | Commit | Date |
|---|---|---|
| runtime docs pin | `15b837c` | 2026-10-15 05:27Z |
| upstream `main` HEAD | `9de307e` | 2026-10-15 15:27Z |
| **adapter pin** | `9de307e` | — |

The two commits in between touch exactly the files that were migrated:
`dm_actions.c`, `dm_cursor.c`, `dm_pages.c`, `dm_rift.c`, `dm_world.c`, and a new
`dm_prof.c` / `dm_prof.h`. The runtime's compat matrix was measured at `15b837c`
and needs re-measuring at `9de307e`.

Upstream cannot be cloned with plain `git clone` from this environment
(`fatal: early EOF`); a codeload tarball works. The two project repositories
clone normally, so this looks like an upstream repository-size issue.

## 6. Data boundary

`docs/scripts/leakcheck.py` over the vendored tree:

```text
files scanned: 251
problems     : 0
```

Four checks: forbidden extensions, NSO/NCA/XCI/NSP/PFS0 magic bytes,
key-shaped files, and unexplained large data files.

Separately confirmed absent: the three tables generated from the user's game
files (`dm_hud_exp.h`, `dm_vault_tab.h`, `dm_bright_levels.inc`) and the startup
prefetch list.
