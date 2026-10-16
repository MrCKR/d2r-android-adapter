# Android port — handoff

The full handoff lives in the runtime repository: **`docs/HANDOFF.md`**. Read that
first. This page is the adapter-side summary.

## This repository's job

39 D2R modules plus the observation-gate tables, built into `libd2r_adapter.a`
and linked into the runtime's shared object. The dependency direction is
**adapter → runtime**: this repository consumes the runtime's host surface and
the runtime never compiles anything from here.

`docs/CONTRACT.md` is the authority on which symbols belong to which side. Read
it before moving anything across the boundary.

## Build

```sh
DM_RUNTIME=/path/to/switch-android-runtime sh tools/build-android-arm64.sh
# adapter android-arm64: compiled ok=39 failed=0
# seam symbols: 337
# → build/android-arm64/libd2r_adapter.a   (1.8 MB)
```

`DM_RUNTIME` is required. The script compiles for
`aarch64-linux-android29` against the runtime's compat layer, and uses the
**system** `ar` because the NDK's `llvm-ar` is an x86_64 binary that cannot run
on an arm64 host.

Headers derived from the user's own game files (`dm_bright_levels.inc` and
friends) are build inputs of this repository, never of the runtime, and are never
committed. Point `DM_GENERATED` at them, or let the stand-ins stand in.

## Where it stands

The archive links into the runtime's shared object with no missing and no
duplicate symbols, and the app now boots the guest to `nnMain` with the adapter
present.

**The adapter's game logic is not yet observed to take effect.** The guest
initialization path being taken is the minimal one, and the guest never reads the
RomFS — no resource is loaded. Whether the gates fire is the open question, and
it is the most promising lead: resource loading plausibly sits behind the same
branch that ends the run.

Two things to know before working on that:

- The ten symbols `CONTRACT.md` lists as this repository's migration debt
  (`dm_cur_tick`, `dm_diag_*`, `dm_freeze_frame`, `dm_request_save`,
  `dm_quiet_difficulty_msg`, `dm_fs_commit_count`, `dm_ingame_now`,
  `dm_loadscreen_up`) are weak stubs on the runtime side right now. A stub that
  reports "nothing is happening" may itself be why the guest sees no reason to
  continue.
- `diag.c` still lives in the runtime's host tree — that is the runtime not being
  D2R-free yet, and `CONTRACT.md` explains why it cannot move until the runtime
  has a boot path that does not require it.

## Pushing

One commit is still local as of writing — `github.com:443` is unreachable from
the development sandbox:

```sh
git push origin HEAD:main     # commit: feat(android): cross-compile the adapter to an arm64 archive
```

Credentials come from `$GITUSER` / `$GITHUBTOKEN`; configure the helper rather
than embedding the token in a URL, which breaks on special characters:

```sh
git config credential.helper '!f() { echo "username=${GITUSER}"; echo "password=${GITHUBTOKEN}"; }; f'
```
