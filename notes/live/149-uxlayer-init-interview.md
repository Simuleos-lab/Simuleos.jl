# uxlayer_init Design — Decisions
**Session**: 2026-02-15

**Issue**: Implement `uxlayer_init(bootstrap)` as Phase 0 of the new `sim_init!` sequence, replacing the old `_buildux!` approach.

**Q**: What should `uxlayer_init(bootstrap)` return?
**A**: `UXLayers.UXLayerView` directly — no Simuleos wrapper type.

**Q**: What sources are available at Phase 0 (before project/home exist)?
**A**: Only bootstrap + ENV + defaults. Local/global settings loaded later. Any init configuration must come from bootstrap or ENV.

**Q**: How should ENV be incorporated?
**A**: Via `_simuleos_parse_env(ENV)::Dict{String,Any}` — stub returning empty Dict for now. Added as the `:env` source in UXLayers.

**Q**: What is the source priority order?
**A**: `:runtime > :env > defaults` at Phase 0. Full order later: `:runtime > :env > :local > :home > defaults`. The bootstrap dict is named `:runtime` in the UXLayer source system (it represents runtime user settings).

**Q**: Should DEFAULTS be set at Phase 0?
**A**: Yes, via `update_defaults!(ux, DEFAULTS)`.

**Q**: What happens to `_buildux!`?
**A**: Replaced entirely by `uxlayer_init` + a later source-loading step.

**Q**: Where does `uxlayer_init` live?
**A**: New file `uxlayer-init-I0x.jl` (pure — only needs bootstrap dict and ENV, no SimOs).

**Q**: Where does `_simuleos_parse_env` live?
**A**: Separate file `env-I0x.jl`.

**Q**: What viewid for the root UXLayerView?
**A**: `"simuleos"` (same as before).

**Q**: Should `uxlayer_init` also set the UXLayer's built-in bootstrap slot?
**A**: No — leave empty. `:runtime` source handles it. NOTE: revise this decision later.

**Q**: Should `uxlayer_init` error on bad bootstrap type?
**A**: Yes — error if bootstrap is not `Dict{String,Any}`.

**Decision**: `uxlayer_init(bootstrap::Dict{String,Any})::UXLayerView` is a pure I0x function in a new file `uxlayer-init-I0x.jl`. It creates a root `UXLayerView("simuleos")`, parses ENV via `_simuleos_parse_env(ENV)` (stub in `env-I0x.jl`), loads `:runtime` and `:env` sources with priority `[:runtime, :env]`, sets `DEFAULTS`, and returns the view. No SimOs dependency. Local/global settings are added in a later phase after project/home init.
