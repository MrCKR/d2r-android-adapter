# Adapter ↔ Runtime contract

中文：[CONTRACT.zh-CN.md](CONTRACT.zh-CN.md)

The seam between `d2r-android-adapter` and `switch-android-runtime`. Everything
the adapter needs from the runtime, and everything the runtime may rely on the
adapter for. Nothing outside this list crosses the boundary.

Every number here is measured by building the adapter with no runtime present —
see [`docs/scripts/build-adapter.sh`](scripts/build-adapter.sh) and
[`MEASURED.md`](MEASURED.md).

## How the list was derived

The vendored D2R sources were compiled against verbatim copies of the upstream
host interface headers (`vendor/d2r-mobile/interface/`, chosen over hand-written
shims so that no type or signature is masked by a wrong guess), then archived:

```sh
sh docs/scripts/build-adapter.sh
# compiled: ok=39 failed=0
# seam (undefined & not defined here): 134
```

Of those 134, 84 are satisfiable by the C library on the Android target. The
remaining **50** are the contract:

| Group | Count | Who provides it |
|---|---:|---|
| runtime host surface | 19 | runtime (this is the stable part) |
| D2R debt currently sitting in the runtime's `diag.c` | 10 | adapter, once `diag.c` is split |
| host globals and small inline delegates | 20 | runtime (same split as above) |
| macOS-only, disappears on Android | 1 | nobody |

## 1. What the runtime must provide — 19 functions

Called by the adapter, defined in the runtime's host layer, and genuinely
generic: none of these needs to know what D2R is, which is why they belong to
the runtime.

| Symbol | Upstream home | Adapter's use |
|---|---|---|
| `dm_3d_quality_mode_get` / `_set` | `hle_oe.c` | read/write the in-game 3D quality preset |
| `dm_3d_scale_cur` | `hle_oe.c` | current dynamic-resolution scale |
| `dm_oe_res_changed` | `hle_oe.c` | output resolution changed |
| `dm_oe_ui_opmode` / `_reads` | `hle_oe.c` | operation mode (handheld/docked) as the UI sees it |
| `dm_opmode` | `hle_oe.c` | operation mode, plain |
| `dm_overlay_file` | `hle_fs.c` | look a file up in the ROMFS overlay layers |
| `dm_save_workdir` / `dm_save_commitdir` | `hle_fs.c` | transactional save directories |
| `dm_fs_d2s_wseq` | `hle_fs.c` | save-file write sequence number |
| `dm_fs_save_poison` | `hle_fs.c` | force the next save to fail (adapter test hook) |
| `dm_seq_next` | `hle_fs.c` | monotonic sequence source |
| `dm_guest_frame` | `hle_os.c` | host present-frame counter |
| `dm_user_clock` / `dm_user_clock_fixed` | `hle_time.c` | guest clock and its determinism pin |
| `dm_test_clock_shift` | `hle_time.c` | shift the guest clock (test switch) |
| `dm_touch_host_is_live` | `touch_mac.c` | is a touch/pointer source driving input |

Three of these (`dm_fs_save_poison`, `dm_test_clock_shift`, and the `_fixed`
variant of the clock pin) exist only for the adapter's own regressions. Keep
them in a release runtime as linkable no-ops rather than removing them, so test
and release builds do not diverge.

`dm_touch_host_is_live` comes from `touch_mac.c`, which is an Apple file the
runtime will not port. Treat it as a **new** runtime-side input-liveness query,
not as a port of that file.

## 2. What the adapter must take back — 10 functions in the runtime's `diag.c`

The largest single finding. `dm/host/diag.c` is 1967 lines of D2R content
(main+0x offsets, observation gates, difficulty handling, HUD numbers, rift
state) that currently lives in the runtime's host directory, and ten functions
in the seam are defined there:

```
dm_cur_tick  dm_diag_difficulty  dm_diag_srv_item  dm_diag_srv_merc
dm_freeze_frame  dm_fs_commit_count  dm_ingame_now  dm_loadscreen_up
dm_quiet_difficulty_msg  dm_request_save
```

Two of these are the clearest evidence that the split is real: `dm_cur_tick` is
the adapter's per-tick clock (the adapter supplies it *and* consumes it), and
`dm_diag_srv_item` / `dm_diag_srv_merc` are diagnostic publishers the adapter
owns.

They cannot move yet: `diag.c` is also the runtime's tick entry and its
observation-gate dispatcher, so removing it stops the runtime booting until a
replacement exists. **These 10 are the adapter's migration debt** — the second
migration, once the runtime has a boot path that does not require `diag.c`.

Until they move, the runtime is not D2R-free. This document is the record.

## 3. Host globals and delegates — 20 symbols

Compile-time dependencies on the runtime's headers. `LOG` alone appears 930
times in the vendored sources, so this surface — not the 50 functions — is what
actually constrains how the two repositories build together.

| Symbol | Upstream home | Note |
|---|---|---|
| `g_mod`, `g_nmod` | `loader.c` / `dm.h` | loaded-module table the adapter patches through |
| `now_ns`, `guest_ns` | `hle_os.c` | clock delegates |
| `uimsg_emit`, `uimsg_subscribe` | `diag.c` | UI message bus; the adapter both subscribes and emits |
| `gate_obs_present`, `gate_obs_set` | `hle.c` | observation-gate registry |
| `g_dm_frz_want`, `g_dm_seek_tp`, `g_dm_seek_tp_x`, `g_dm_seek_tp_y` | `diag.c` | adapter state published through runtime globals |
| `g_dm_l_presses` | `hle_hid.c` | controller press-edge count |
| `g_dm_mount_seed_hook`, `g_dm_pre_commit_hook` | `hle_fs.c` | save-transaction hooks the adapter registers |
| `g_dm_tz_live_ns`, `g_dm_tz_time` | `hle_time.c` | clock state |
| `g_swkbd_numeric_max` | `hle_swkbd.c` | software-keyboard numeric limit |
| `thread_selfcounts` | libc/Darwin syscall | used via `dm_prof.c` |
| `front_game_res` | `front.h` | provided by whichever front end is built |

Two ways to break this dependency, in order of preference:

1. **The runtime publishes a small adapter SDK header** re-exporting exactly
   this list. The adapter vendors that header instead of `dm.h` / `hle.h`. The
   contract becomes explicit instead of incidental.
2. **The adapter vendors the headers** (what it does today:
   `vendor/d2r-mobile/interface/`, verbatim copies). Works with zero runtime
   involvement but the copies can drift.

## 4. Android-specific: the host-call registry must be renegotiated

Upstream's `hle.h` reserves `svc` numbers 0x80–0x8e for host calls, and **six of
the fifteen belong to the adapter**:

| No. | Purpose | Upstream cut | Owner |
|---|---|---|---|
| 0x87 | ground item appearance path | `dm_dropfilter.c` | **adapter** |
| 0x88 | item landing drop sound | `dm_dropfilter.c` | **adapter** |
| 0x89 | rift exit rerouting | `dm_rift.c` | **adapter** |
| 0x8a | player spawn point on run entry | `dm_townwp.c` | **adapter** |
| 0x8b | corpse drop point on run entry | `dm_townwp.c` | **adapter** |
| 0x8c | act saved while in a rift | `dm_rift.c` | **adapter** |
| 0x8d | extra mercenary equipment slots | `dm_rift.c` | **adapter** |
| 0x8e | client-side check for the same | `dm_rift.c` | **adapter** |
| 0x80–0x86 | TACT/Granny decode, packet delivery, private skill HUD | `hle_tact.c`, `hle_granny.c`, `hle_private_aim.c`, `diag.c` | runtime |

The registry is a **shared, numbered namespace** owned by the runtime's dispatch
path but partly populated by adapter cuts. It has to be allocated explicitly
rather than the adapter inheriting 0x87–0x8e, because the runtime may want those
numbers for its own gates. Agree on a range split before either side adds any.

## 5. What the adapter provides to the runtime

The runtime's startup and tick paths call into the adapter. These are the
adapter's obligations; the runtime may rely on all of them.

| Symbol | Called from (upstream) |
|---|---|
| `dm_padmode_boot` | `main.c` — install touch-overlay layout before the game builds panels |
| `dm_guest_spawn_selftest` | `main.c` (test builds) |
| `dm_term_install` | `main.c` — graceful SIGTERM |
| `dm_cloud_boot` | `main.c` — offline/cloud save reconciliation at startup |
| `dm_server_tick` | `hle_hid.c` — per-tick pump |
| `dm_cur_tick` | `diag.c`, `touch_mac.c` — current tick (see §2: definition should move here) |
| `dm_prof_mark` | `main.c`, `diag.c` — boot timeline marker |
| `dm_pad_hook` | `hle_hid.c` — controller event intake |
| `dm_romfs_validate` | `romfs_validate.c` — validate the user's game files before loading |
| `dm_gate` | `entry.S` — the `svc` / `tpidrro_el0` gate target |
| `dm_bright_server_tick` | `diag.c` |
| `dm_freetp_server_step` | `diag.c` |

## 6. What the runtime must add on Android

Not part of the symbol seam — compile-time gaps the adapter hits, all generic
and all small. Listed here so the runtime team can size them:

| Need | Upstream users | Effort |
|---|---|---|
| `CC_SHA1` + `CC_SHA1_DIGEST_LENGTH` | `dm_padmode.c` | low — the compat layer has MD5 and SHA256; add SHA1 the same way |
| `arc4random_uniform` | `dm_namegen.c`, `dm_rift.c` | low |
| `clock_gettime_nsec_np` + `CLOCK_UPTIME_RAW` | `dm_textbox.c`, `dm_bossrush.c` | low |
| `st_mtimespec` | `dm_cloudmerge.c`, `dm_cloudsync.c`, `dm_rift.c` | low — struct field alias to `st_mtim` |
| `getdtablesize` | `hle_fdstat.c` | low |
| guest read/write helpers (`tk_rd` and friends) | most adapter modules | medium — the adapter patches guest memory constantly; this is the hot path |
