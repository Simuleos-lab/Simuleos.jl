# Reader module - SessionReader management
# Thin wrapper for now — delegates to handlers in Core

module Reader

import ..Core

"""
    _get_reader()

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].reader` on first call

Get the active SessionReader from SIMOS[].reader. Creates one if needed.
"""
function _get_reader()::Core.SessionReader
    sim = Core._get_sim()
    if isnothing(sim.reader)
        sim.reader = Core.SessionReader()
    end
    return sim.reader
end

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module Reader
