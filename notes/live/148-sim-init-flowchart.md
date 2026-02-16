# sim_init Flowchart

Complete call graph of every action triggered by `sim_init(proj_path; bootstrap)`.

```
│   # FEEDBACK: we need to make `sim_init!` act on a simos
│   # the global one `sim_init(simos::SimOs, proj_path; bootstrap)` will just call `sim_init!`
│   # FEEDBACK: we are dropping `proj_root` as an explicit arg
│   # all must be set on the bootstrap data
│
sim_init!(simos::SimOs; bootstrap)                           [sys-init-I3x.jl:13]
│
│  ── PHASE O: INIT UXLAYER ────────────────────────────────────────
│   # FEEDBACK: we need `uxlayer_init(bootstrap)::UXLayer`
│   # this is important because the init of the system should also depend on uxlayer settings
│   ux = uxlayer_init(bootstrap) # error if init fail
│   # FEEDBACK: we need to have a set of bootstraping methods
│   # - for instance, we need to be able to load settings and deal with ENV before having fuly form drivers
│   # - those methods whould only be required on init methods... 
│   
│   # FEEDBACK: Improtant, bootstrap needs to be high priority on uxlayer settings
│   # - here at SimuleOs is like runtime config
│
│   # FEEDBACK: create a helper for normalizing paths
├─ proj_root = _path_normalize(proj_path)
├─ GUARD: isfile(proj_root) → error
│
│  ── PHASE 1: HOME INIT ──────────────────────────────────────────
│
│   # FEEDBACK: nice, yes, we are opting for building a driver object first
│   # and then completed on its own init
├─ home = SimuleosHome(path = ...)                       [base-I0x.jl:30]
│    └─ path = get(bootstrap, "homePath", ...)
│         └─ home_simuleos_default_path()                [home-I0x.jl:5]
│              └─ joinpath(homedir(), ".simuleos")
│
├─ init_home!(home)                                      [home-I1x.jl:8]
│    ├─ hpath = home_path(home) → home.path
│    ├─ mkpath(hpath)                        ← DISK: creates ~/.simuleos/
│    └─ mkpath(registry_path(home))          ← DISK: creates ~/.simuleos/registry/
│         └─ joinpath(home.path, "registry")
│
│  ── PHASE 2: PROJECT INIT ───────────────────────────────────────
│
├─ proj = Project(root_path = proj_root)                 [base-I0x.jl:20]
│    ├─ simuleos_dir = _simuleos_dir(root_path)          [fs-I0x.jl:4]
│    │    └─ joinpath(root_path, ".simuleos")
│    └─ blobstorage = BlobStorage(simuleos_dir)
│
├─ already_init = proj_is_init(proj)                     [project-I1x.jl:11]
│    └─ isfile(proj_json_path(proj))
│         └─ _proj_json_path(root_path)                  [project-I0x.jl:28]
│              └─ joinpath(_simuleos_dir(root), "project.json")
│
├─ proj_init!(proj)                                      [project-I1x.jl:16]
│    ├─ proj_sim = simuleos_dir(proj) → proj.simuleos_dir
│    ├─ proj_json = proj_json_path(proj)
│    ├─ mkpath(proj_sim)                     ← DISK: creates {root}/.simuleos/
│    │
│    ├─ IF NOT exists(proj_json):           ← FIRST-TIME PATH
│    │    ├─ proj.id = string(uuid4())
│    │    └─ open(proj_json, "w")            ← DISK: writes project.json {"id":"<uuid>"}
│    │
│    └─ IF exists(proj_json):               ← IDEMPOTENT PATH
│         ├─ open(proj_json, "r") → JSON3.read → pjdata
│         ├─ GUARD: pjdata["id"] missing → error
│         └─ proj.id = string(pjdata["id"])
│
├─ @info (log message depending on already_init)
│
│  ── PHASE 3: ACTIVATION ─────────────────────────────────────────
│
└─ sim_activate(proj_root, bootstrap)                    [SIMOS-I3x.jl:55]
     │
     ├─ proj_path = abspath(proj_path)
     ├─ GUARD: isfile(proj_path) → error
     │
     ├─ _proj_validate_folder(proj_path)                 [project-I0x.jl:17]
     │    └─ GUARD: !isfile(.simuleos/project.json) → error
     │
     ├─ sim = SIMOS[]
     ├─ IF isnothing(sim):
     │    ├─ sim = SimOs()                               [base-I0x.jl:10]
     │    │    └─ SimOs(Dict(), nothing, nothing, nothing, nothing)
     │    └─ SIMOS[] = sim                   ← GLOBAL: set singleton
     │
     ├─ sim.bootstrap = bootstrap            ← MUTATE: store bootstrap dict
     │
     ├─ sim.project = _load_project(proj_path)           [SIMOS-I0x.jl:3]
     │    ├─ pjpath = _proj_json_path(proj_path)
     │    ├─ open(pjpath, "r") → JSON3.read → pjdata
     │    ├─ GUARD: pjdata["id"] missing → error
     │    ├─ sd = _simuleos_dir(proj_path)
     │    └─ return Project(id=..., root_path=...,
     │         simuleos_dir=sd, blobstorage=BlobStorage(sd))
     │
     ├─ sim.home = init_home!(               ← MUTATE: set home
     │    SimuleosHome(path = get(bootstrap, "homePath",
     │         home_simuleos_default_path()))
     │  )
     │    ├─ mkpath(~/.simuleos/)            ← DISK: (idempotent)
     │    └─ mkpath(~/.simuleos/registry/)   ← DISK: (idempotent)
     │
     └─ _buildux!(sim, bootstrap)                        [uxlayer-I2x.jl:18]
          │
          ├─ ux = UXLayers.UXLayerView("simuleos")
          │
          ├─ local_settings =                            [uxlayer-I0x.jl:22]
          │    _load_settings_json(proj_settings_path(sim))
          │    └─ path = {root}/.simuleos/settings.json
          │    └─ if !isfile → Dict()
          │    └─ if isfile → JSON3.read → Dict
          │
          ├─ global_settings =
          │    _load_settings_json(home_settings_path(sim))
          │    └─ path = ~/.simuleos/settings.json
          │    └─ if !isfile → Dict()
          │    └─ if isfile → JSON3.read → Dict
          │
          ├─ UXLayers.refresh!(ux,
          │    {:bootstrap => bootstrap,
          │     :local => local_settings,
          │     :global => global_settings},
          │    [:bootstrap, :local, :global])
          │
          ├─ UXLayers.update_bootstrap!(ux, sim.bootstrap)
          ├─ UXLayers.update_defaults!(ux, DEFAULTS)
          │
          └─ sim.ux = ux                     ← MUTATE: set UX layer
```

## Side Effects Summary

| Action | Where | Idempotent? |
|---|---|---|
| `mkpath(~/.simuleos/)` | `init_home!` (called 2x) | yes |
| `mkpath(~/.simuleos/registry/)` | `init_home!` (called 2x) | yes |
| `mkpath({root}/.simuleos/)` | `proj_init!` | yes |
| `write project.json` | `proj_init!` | yes (skips if exists) |
| `SIMOS[] = sim` | `sim_activate` | creates once, reuses |
| `sim.bootstrap = ...` | `sim_activate` | overwrite |
| `sim.project = ...` | `sim_activate` | overwrite |
| `sim.home = ...` | `sim_activate` | overwrite |
| `sim.ux = ...` | `_buildux!` | overwrite |

## Notes

- `init_home!` runs **twice** — once in `sim_init` directly, and again inside `sim_activate`. Both calls are idempotent.
- `project.json` is read **twice** — once in `proj_init!` and again in `_load_project` inside `sim_activate`.
