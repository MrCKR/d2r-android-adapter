# D2R Adapter Plan

## Reference

The Apple implementation at `jhaizhou-ops/d2r-mobile` is a technical reference only. It must not be copied into the generic runtime without first separating platform-independent behavior from D2R-specific behavior.

## Extraction checklist

- [ ] classify every host feature as generic or D2R-specific;
- [ ] identify all Apple-only code paths;
- [ ] describe each D2R patch by version fingerprint and reason;
- [ ] convert hard-coded addresses into generated, versioned metadata;
- [ ] convert shader data requirements into an offline local build step;
- [ ] make missing services fail with actionable diagnostics;
- [ ] add a replayable boot trace for the first menu path.

## Acceptance gates

### Gate 1: identify

The adapter recognizes only the intended game version and rejects unknown files before patching.

### Gate 2: load

The runtime maps the adapter's test module, applies validated relocations, and prints a deterministic startup trace.

### Gate 3: render

The D2R graphics profile creates a Vulkan device, loads a locally generated shader/pipeline set, and reaches the title/menu path.

### Gate 4: play offline

A new character can enter an offline game, accept touch/gamepad input, play audio, save, quit, and reload.

### Gate 5: device endurance

The target phone can run a repeatable workload while collecting FPS, frame time, memory, temperature and crash data.

## Version policy

Every adapter release must identify:

- upstream reference commit;
- exact game build/version;
- patch metadata version;
- shader toolchain version;
- Runtime SDK version;
- tested Android API and GPU driver.
