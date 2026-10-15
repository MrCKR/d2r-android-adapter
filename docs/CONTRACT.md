# Adapter ↔ Runtime contract

中文：[CONTRACT.zh-CN.md](CONTRACT.zh-CN.md)

Everything the adapter needs from the runtime, and everything the runtime may
rely on the adapter for. Nothing outside this list crosses the boundary.

**Verified two ways:**

- `docs/scripts/build-adapter.sh` — the 39 D2R modules compile with no runtime
  present: `compiled: ok=39 failed=0`
- `docs/scripts/link-test.sh` — they link against a stub runtime defining
  exactly the 50 symbols below, and nothing else. `LINK OK — the contract is
  complete`. A negative control (deleting three stub symbols) makes the link
  fail, so the test does detect a broken contract.

Signatures below are **extracted from the upstream sources that define each
symbol**, not read off a header. Several differ from what the declarations
suggest — see the notes.

## The seam, in one table

| Group | Count | Who provides it | State |
|---|---:|---|---|
| A. runtime host surface | 19 | runtime | stable, implement these |
| B. D2R debt in the runtime's `diag.c` | 10 | adapter, after the second migration | stubbed for now |
| C. host globals and delegates | 20 | runtime | see the two header options below |
| D. macOS-only | 1 | nobody | disappears on Android |

## Group A — runtime host surface (19)

| Symbol | Signature | Upstream home |
|---|---|---|
| `dm_3d_quality_mode_get` | `int (void)` | `hle_oe.c` |
| `dm_3d_quality_mode_set` | `void (int mode)` | `hle_oe.c` |
| `dm_3d_scale_cur` | `float (void)` | `hle_oe.c` |
| `dm_oe_res_changed` | `void (void)` | `hle_oe.c` |
| `dm_oe_ui_opmode` | `void (int m)` | `hle_oe.c` |
| `dm_oe_ui_opmode_reads` | `uint32_t (void)` | `hle_oe.c` |
| `dm_opmode` | `int (void)` | `hle_oe.c` |
| `dm_overlay_file` | `int (const char *rel, char *out, size_t n)` | `hle_fs.c` |
| `dm_save_commitdir` | `const char *(void)` | `hle_fs.c` |
| `dm_save_workdir` | `const char *(void)` | `hle_fs.c` |
| `dm_fs_d2s_wseq` | `uint64_t (void)` | `hle_fs.c` |
| `dm_fs_save_poison` | `void (int e)` | `hle_fs.c` |
| `dm_seq_next` | `uint64_t (void)` | `hle_fs.c` |
| `dm_guest_frame` | `uint64_t (void)` | `hle_os.c` |
| `dm_user_clock` | `int64_t (void)` | `hle_time.c` |
| `dm_user_clock_fixed` | `int (void)` | `hle_time.c` |
| `dm_test_clock_shift` | `void (int64_t d)` | `hle_time.c` |
| `dm_touch_host_is_live` | `int (void)` | `touch_mac.c` |
| `dm_stick_last_ns` | `uint64_t (void)` | `hle_hid.c` |

Notes for whoever implements these on Android:

- **`dm_3d_scale_cur` returns `float`, not `double`.** Easy to get wrong from
  the call sites, which assign it to wider types.
- **`dm_fs_save_poison` returns `void` and takes an errno.** It is a test hook
  that arms a forced save failure, not a predicate. Keep it in release builds
  as a no-op so test and release do not diverge.
- **`dm_touch_host_is_live` comes from `touch_mac.c`**, an Apple file the runtime
  will not port. Treat it as a *new* runtime-side input-liveness query rather
  than a port of that file.
- `dm_save_workdir` / `dm_save_commitdir` may return `NULL`; the adapter handles
  that. Both walk an internal mount table on every call, so a runtime that
  implements them should cache rather than recompute per tick.

## Group B — D2R debt in the runtime's `diag.c` (10)

`dm/host/diag.c` is 1967 lines of D2R content (main+0x offsets, observation
gates, difficulty handling, HUD numbers, rift state) currently living in the
runtime's host directory. Ten seam symbols are defined there:

| Symbol | Signature |
|---|---|
| `dm_cur_tick` | `uint32_t (void)` |
| `dm_diag_difficulty` | `int (void)` |
| `dm_diag_srv_item` | `uint64_t (uint32_t id)` |
| `dm_diag_srv_merc` | `int (uint32_t id, int *hp, int *mx, int *healing)` |
| `dm_freeze_frame` | `void (int want)` |
| `dm_fs_commit_count` | `uint64_t (void)` |
| `dm_ingame_now` | `int (void)` |
| `dm_loadscreen_up` | `int (void)` |
| `dm_quiet_difficulty_msg` | `void (int on)` |
| `dm_request_save` | `int (void)` |

Two are the clearest evidence that this split is real: `dm_cur_tick` is the
adapter's per-tick clock (the adapter supplies it *and* consumes it), and
`dm_diag_srv_item` / `dm_diag_srv_merc` are diagnostic publishers the adapter
owns outright.

They cannot move yet — `diag.c` is also the runtime's tick entry and its
observation-gate dispatcher, so removing it stops the runtime booting until a
replacement exists. **These 10 are the adapter's migration debt**, payable once
the runtime has a boot path that does not require `diag.c`.

Until they move, the runtime is not D2R-free. This document is the record.

## Group C — host globals and delegates (20)

Compile-time dependencies. `LOG` alone appears 930 times in the vendored
sources, so this surface — not the 50 functions — is what actually constrains
how the two repositories build together.

| Symbol | Type | Note |
|---|---|---|
| `g_mod` | `module_t[MAX_MOD]` | loaded-module table the adapter patches through |
| `g_nmod` | `int` | |
| `now_ns` | `uint64_t (void)` | |
| `guest_ns` | `uint64_t (void)` | |
| `uimsg_emit` | `void (const char *, const char *, const char *)` | **three `const char *`**, not a payload pointer |
| `uimsg_subscribe` | `void (void (*cb)(const char *, const char *, const char *))` | **one argument**: the callback carries all three strings |
| `gate_obs_set` | `void (int id, void (*fn)(const uint64_t *regs))` | |
| `gate_obs_present` | `int (int id)` | |
| `g_dm_frz_want` | `int` | adapter state published through a runtime global |
| `g_dm_seek_tp` | `int` | |
| `g_dm_seek_tp_x` | `int` | |
| `g_dm_seek_tp_y` | `int` | |
| `g_dm_l_presses` | `int` | |
| `g_dm_mount_seed_hook` | `void (*)(const char *save_dir)` | **function pointer, not `int`**; must start `NULL` |
| `g_dm_pre_commit_hook` | `void (*[5])(const char *workdir)` | **array of 5 function pointers**; slots 0–4 are stash, chronicle, pouch, rift, cloud merge |
| `g_dm_tz_live_ns` | `uint64_t` | |
| `g_dm_tz_time` | `int64_t` | |
| `g_swkbd_numeric_max` | `int` | ≥0 = next system input box is numeric |
| `thread_selfcounts` | `int (int type, void *buf, size_t nbytes)` | libc/Darwin syscall; used via `dm_prof.c` |
| `front_game_res` | `uint64_t (int docked)` | provided by whichever front end is built |

The two hook globals matter most: they are the adapter registering *into* the
runtime's save path, so on Android they must be defined (as `NULL`) even in a
build that has no adapter, or the runtime's own code will not link.

**Two ways to break this compile-time dependency**, in order of preference:

1. **The runtime publishes a small adapter SDK header** re-exporting exactly this
   list. The adapter vendors that header instead of `dm.h` / `hle.h`. The
   contract becomes explicit rather than incidental.
2. **The adapter vendors the headers** — what it does today
   (`vendor/d2r-mobile/interface/`, verbatim copies of `dm.h`, `hle.h`,
   `front.h`). Works with zero runtime involvement, but the copies can drift.

Option 2 also means the adapter currently carries declarations the runtime may
not actually export (the whole `nn::` HLE surface in `hle.h`), which is
harmless for compiling but is not a promise.

## Group D — macOS-only (1)

| Symbol | Signature | Note |
|---|---|---|
| `dm_gfx_shot_at` | `void (long k, const char *path)` | defined in `nvn_mtl.m` upstream; Android's Vulkan backend replaces it |

## Android-specific: the host-call registry must be renegotiated

Upstream's `hle.h` reserves `svc` numbers 0x80–0x8e for host calls. **Eight of
the fifteen belong to adapter cuts:**

| No. | Purpose | Cut site | Owner |
|---|---|---|---|
| 0x87 | ground item appearance path | `dm_dropfilter.c` | **adapter** |
| 0x88 | item landing drop sound | `dm_dropfilter.c` | **adapter** |
| 0x89 | rift exit rerouting | `dm_rift.c` | **adapter** |
| 0x8a | player spawn point on run entry | `dm_townwp.c` | **adapter** |
| 0x8b | corpse drop point on run entry | `dm_townwp.c` | **adapter** |
| 0x8c | act saved while in a rift | `dm_rift.c` | **adapter** |
| 0x8d | extra mercenary equipment slots | `dm_rift.c` | **adapter** |
| 0x8e | client-side check for the same | `dm_rift.c` | **adapter** |
| 0x80–0x86 | TACT/Granny decode, packet delivery, private skill HUD/aim | `hle_tact.c`, `hle_granny.c`, `hle_private_aim.c`, `diag.c` | runtime |

The registry is a **shared, numbered namespace**: owned by the runtime's
dispatch path but partly populated by adapter cuts. It must be allocated
explicitly rather than the adapter inheriting 0x87–0x8e, because the runtime may
want those numbers for its own gates. Agree on the range split before either
side adds another entry.

This is also the one place where the "does it need to know it is D2R?" rule
gives an ambiguous answer: the numbers live in a runtime header, the meanings
are pure D2R. Treat the *number range* as the runtime's and the *semantics* as
the adapter's.

## What the adapter provides to the runtime

The runtime's startup and tick paths call into the adapter. These are the
adapter's obligations.

| Symbol | Called from (upstream) |
|---|---|
| `dm_padmode_boot` | `main.c` — install touch-overlay layout **before** the game builds its panels |
| `dm_guest_spawn_selftest` | `main.c` (test builds) |
| `dm_term_install` | `main.c` — graceful SIGTERM |
| `dm_cloud_boot` | `main.c` — offline/cloud save reconciliation at startup |
| `dm_server_tick` | `hle_hid.c` — per-tick pump |
| `dm_cur_tick` | `diag.c`, `touch_mac.c` (see Group B — should move here) |
| `dm_prof_mark` | `main.c`, `diag.c` — boot timeline marker |
| `dm_pad_hook` | `hle_hid.c` — controller event intake |
| `dm_romfs_validate` | `romfs_validate.c` — validate the user's game files before loading |
| `dm_gate` | `entry.S` — the `svc` / `tpidrro_el0` gate target |
| `dm_bright_server_tick` | `diag.c` |
| `dm_freetp_server_step` | `diag.c` |

Ordering constraint worth repeating: `dm_padmode_boot` must run before the game
builds its panels, or the touch layout is never installed.

## What the runtime must add on Android

Compile-time gaps the adapter hits. All generic, all small.

| Need | Upstream users | Effort |
|---|---|---|
| `CC_SHA1` + `CC_SHA1_DIGEST_LENGTH` | `dm_padmode.c` | low — the compat layer has MD5 and SHA256; add SHA1 the same way |
| `arc4random_uniform` | `dm_namegen.c`, `dm_rift.c` | low |
| `clock_gettime_nsec_np` + `CLOCK_UPTIME_RAW` | `dm_textbox.c`, `dm_bossrush.c` | low |
| `st_mtimespec` | `dm_cloudmerge.c`, `dm_cloudsync.c`, `dm_rift.c` | low — field alias to `st_mtim` |
| `getdtablesize` | `hle_fdstat.c` | low |
| guest read/write helpers (`tk_rd` and friends) | most adapter modules | **medium — the adapter patches guest memory constantly; this is the hot path** |
