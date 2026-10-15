# Migration 1 — vendoring the D2R-specific sources

Status: **done**, timeboxed to what can be measured without a runtime.
Vendored tree is 250 files / 6.0 MiB, pinned to one upstream commit.

## What was migrated

From `jhaizhou-ops/d2r-mobile` at
`9de307ecaff42b3c9d45e58992c848ee89b8f6a1` into `vendor/d2r-mobile/`, keeping
upstream's path layout so a file-by-file diff against upstream stays trivial.

| Vendored path | Files | Size | Why it is D2R-specific |
|---|---:|---:|---|
| `dm/host/dm_*.c` `dm_*.h` | 62 | 2.3 MB | the 39 feature modules: loot filter, runewords, rift, vault, HUD, cursor, pages … |
| `dm/gfx/nvn/` fact tables + `include/nvn.h` | 31 | 2.9 MB | shader map/reflection, PSO manifest, NVN name and slot tables, 3rd-party NVN header |
| `dm/gfx/tools/` | (in above) | — | the offline shader translation chain; the D2R shader set is its input |
| `dm/i18n/` | 5 | 91 KB | the D2R-specific string table and its literal gate |
| `dm/tools/` | 36 | 355 KB | `patch_nso.py` (version-keyed rewrite rules), resource readers, generators |
| `dm/verify/` | 102 | 897 KB | rewrite-equivalence and screenshot/touch regression |
| `dm/ios/Sources/dm_touch_*` | 12 | 222 KB | the touch layer; Apple front end excluded, the C core kept |
| `dm/data/casc_overlay/` | 1 | 11 KB | borrowed-path registry |
| `dm/PRODUCT`, `dm/ios/tools/touchrectv1_patch.json` | 2 | — | build codename; original controller layout description |

`vendor/MANIFEST.tsv` records the pinned commit and a SHA-256 per file.

## What was deliberately left out

| Left out | Reason |
|---|---|
| `dm/host/hle_*.c`, `loader.c`, `thread.c`, `crash.c`, `romfs_validate.c` | generic runtime host layer — runtime's, settled before this migration |
| `dm/host/{dm.h, hle.h, front.h}` | host-owned headers (see `CONTRACT.md` for how the adapter reaches them) |
| `dm/host/{main.c, entry.S, app_mac.m, memstat.m, touch_mac.*, front_mac.m}` | process entry and Apple front end |
| `dm/gfx/nvn/nvn_mtl.m` (6386 lines) | NVN→Metal backend; zero reuse on Vulkan |
| `dm/gfx/nvn/{nvn_thunks.S, nvn_entry.S, nvn_refl.m}` | generated for / written against the Metal backend |
| `dm/ios/Sources/{front_ios.m, main.m, cloud_ios.m, asset_dl.m, *.m}` | Apple shell |
| `dm/tools/{mac_app.sh, guirun.sh}` | Apple packaging / GUI launch |
| `dm/host/dm_touch_game_identity.c` | uses `mach/vm_map.h`; must be rewritten, not ported |

## Two version-policy items the runtime team should decide

1. **Pin.** The runtime's docs pin `15b837c` (2026-10-15 05:27Z). Upstream has
   since moved to `9de307e` (2026-10-15 15:27Z), and the two intervening commits
   touch exactly the files in this migration: `dm_actions.c`, `dm_cursor.c`,
   `dm_pages.c`, `dm_rift.c`, `dm_world.c`, plus a new `dm_prof.c/h`. The
   adapter is pinned at `9de307e`; the runtime's compat matrix was measured
   against `15b837c`. Re-measuring it against `9de307e` is a runtime-side task.

2. **Upstream clone is unreliable.** A plain `git clone` of the upstream repo
   ends in `fatal: early EOF` from this environment; a codeload tarball works.
   The two project repositories clone normally, so this looks like an upstream
   repository-size/network issue rather than a local one. Worth a retry note in
   the docs so it does not look like a local misconfiguration.

## Data boundary

A mechanical check over the vendored tree (`docs/scripts/leakcheck.py`) reports
0 problems across 4 tests: no forbidden extensions, no NSO/NCA/XCI/NSP/PFS0
magic bytes, no key-shaped files, no unexplained large data files.

What the tree does contain, per upstream's own `docs/DERIVED.md`: the
`main+0x…` addresses (872 occurrences in 63 files, valid for game build
`3.3.94012` only), the rewrite rules in `patch_nso.py`, the shader/NVN fact
tables, the string table, and a small number of internal game names. Upstream
classifies these as records of facts about the game rather than game content,
and they cannot be regenerated without the game; they are carried here under
that reading.

Two things that must **not** be committed by any downstream build, and are not
present: the tables generated from the user's own game files
(`dm_hud_exp.h`, `dm_vault_tab.h`, `dm_bright_levels.inc`) and the startup
prefetch list.

**Licence.** Upstream is MIT. This repository needs an `LICENSE` and a `NOTICE`
before this tree is published — it currently has neither. Additionally,
`patch_nso.py` carries 7 rewrite rules upstream attributes to a community
offline fix (LFS Mod Offline Fix) whose author upstream could not identify;
that provenance must be stated in the adapter's own derived-material note
rather than left implied.
