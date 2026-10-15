/*
 * Stub runtime — proof that docs/CONTRACT.md is complete.
 *
 * Defines exactly the 50 symbols the adapter needs, with the signatures taken
 * from the upstream sources that own them (extracted, not guessed). If the
 * adapter links cleanly against this and nothing else, the contract is neither
 * missing a symbol nor overstating one.
 *
 * Nothing here is functional. Every body returns a harmless zero. This file is
 * a test fixture, not a runtime.
 *
 * Group A (19): genuine runtime host surface.
 * Group B (10): D2R content that currently lives in the runtime's diag.c.
 *               Listed here so the adapter can be validated now; the second
 *               migration moves the real definitions into the adapter.
 * Group C (20): host globals and small delegates.
 * Group D  (1): macOS-only. Present only so a Linux/Android link resolves.
 */
#include <stddef.h>
#include <stdint.h>

/* ---------- host types (from the runtime's dm.h) ------------------------- */
#define MAX_MOD 8
typedef struct { char name[16]; uint8_t *base; size_t size; } module_t;

/* ======== Group A: runtime host surface (19) ============================= */
static _Atomic int g_3d_quality_mode_stub;
int      dm_3d_quality_mode_get(void)            { return 0; }
void     dm_3d_quality_mode_set(int mode)        { (void)mode; }
float    dm_3d_scale_cur(void)                   { return 1.0f; }
void     dm_oe_res_changed(void)                 { }
void     dm_oe_ui_opmode(int m)                  { (void)m; }
uint32_t dm_oe_ui_opmode_reads(void)             { return 0; }
int      dm_opmode(void)                         { return 0; }
int      dm_overlay_file(const char *rel, char *out, size_t n) { (void)rel; (void)out; (void)n; return 0; }
const char *dm_save_commitdir(void)              { return NULL; }
const char *dm_save_workdir(void)                { return NULL; }
uint64_t dm_fs_d2s_wseq(void)                    { return 0; }
void     dm_fs_save_poison(int e)                { (void)e; }
uint64_t dm_seq_next(void)                       { return 0; }
uint64_t dm_guest_frame(void)                    { return 0; }
int64_t  dm_user_clock(void)                     { return 0; }
int      dm_user_clock_fixed(void)               { return 0; }
void     dm_test_clock_shift(int64_t d)          { (void)d; }
int      dm_touch_host_is_live(void)             { return 0; }
uint64_t dm_stick_last_ns(void)                  { return 0; }

/* ======== Group B: D2R debt currently in the runtime's diag.c (10) ======== */
/* Stubbed until the second migration moves the real bodies into the adapter. */
uint32_t dm_cur_tick(void)                                   { return 0; }
int      dm_diag_difficulty(void)                            { return -1; }
uint64_t dm_diag_srv_item(uint32_t id)                       { (void)id; return 0; }
int      dm_diag_srv_merc(uint32_t id, int *hp, int *mx, int *healing) {
    (void)id; if (hp) *hp = 0; if (mx) *mx = 0; if (healing) *healing = 0; return 0; }
void     dm_freeze_frame(int want)                           { (void)want; }
uint64_t dm_fs_commit_count(void)                            { return 0; }
int      dm_ingame_now(void)                                 { return 0; }
int      dm_loadscreen_up(void)                              { return 0; }
void     dm_quiet_difficulty_msg(int on)                     { (void)on; }
int      dm_request_save(void)                               { return 0; }

/* ======== Group C: host globals and delegates (20) ====================== */
module_t g_mod[MAX_MOD];
int      g_nmod;
int      g_dm_frz_want;
int      g_dm_l_presses;
int      g_dm_seek_tp;
int      g_dm_seek_tp_x;
int      g_dm_seek_tp_y;
int64_t  g_dm_tz_time;
int      g_swkbd_numeric_max = -1;
uint64_t g_dm_tz_live_ns;

/* Adapter-registered hooks. Note the empty initialiser: the adapter tests the
   pointer before calling, so the runtime must define them as NULL. */
void (*g_dm_mount_seed_hook)(const char *save_dir);
void (*g_dm_pre_commit_hook[5])(const char *workdir);

uint64_t guest_ns(void)          { return 0; }
uint64_t now_ns(void)            { return 0; }

/* The real signatures, recovered from the call sites — these differ from what
   a first reading of the header suggests. */
void uimsg_emit(const char *a, const char *b, const char *c) { (void)a; (void)b; (void)c; }
void uimsg_subscribe(void (*cb)(const char *a, const char *b, const char *c)) { (void)cb; }
void gate_obs_set(int id, void (*fn)(const uint64_t *regs)) { (void)id; (void)fn; }
int  gate_obs_present(int id) { (void)id; return 0; }

int         thread_selfcounts(int type, void *buf, size_t nbytes) { (void)type; (void)buf; (void)nbytes; return 0; }
uint64_t    front_game_res(int docked) { (void)docked; return 0; }

/* ======== Group D: macOS-only (1) ======================================= */
/* Defined by nvn_mtl.m upstream, which Android does not port. Present so a
   Linux/Android link resolves; the runtime's Vulkan backend replaces it. */
void dm_gfx_shot_at(long k, const char *path) { (void)k; (void)path; }
