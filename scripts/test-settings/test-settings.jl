using Simuleos

## ======================================
# Setup: Activate project with args
# ======================================

# Option 1: Explicit path with args (highest priority source)
args = Dict{String,Any}(
    "max_blob_size" => 1048576,
    "compression" => true
)
Simuleos.activate(@__DIR__, args)

# Option 2: Auto-detect from pwd (empty args)
Simuleos.activate()

## ======================================
# Access settings from SimOS (cold path)
# ======================================

# Get setting (errors if not found)
val = Simuleos.settings(Simuleos.SIMOS, "max_blob_size")

# Get setting with default (returns default if not found)
val = Simuleos.settings(Simuleos.SIMOS, "compression", false)

## ======================================
# Access settings from Session (hot path, cached)
# ======================================

# Initialize session (no block)
@sim_session "my_session"

# Get the session
session = Simuleos.ContextIO._get_session()

# Get setting (errors if not found)
val = Simuleos.settings(session, "max_blob_size")

# Get setting with default
val = Simuleos.settings(session, "compression", false)

# Continue with captures and commits
@sim_capture "step1"
@sim_commit "checkpoint1"

## ======================================
# Bootstrap settings (set before activate)
# ======================================

Simuleos.SIMOS.bootstrap = Dict{String,Any}(
    "default_format" => "json"
)
Simuleos.activate("/path/to/project", args)

## ======================================
# Priority Order (first hit wins)
# ======================================
# 1. args          - passed to activate()
# 2. bootstrap     - from SimOS.bootstrap
# 3. local JSON    - .simuleos/settings.json
# 4. global JSON   - ~/.simuleos/settings.json
# 5. DEFAULTS      - Simuleos.DEFAULTS constant