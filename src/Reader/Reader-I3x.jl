"""
    _get_reader()

I3x — reads `SIMOS[]` via `_get_sim()`; writes `SIMOS[].reader` on first call

Get the active SessionReader from SIMOS[].reader. Creates one if needed.
"""
function _get_reader()::Kernel.SessionReader
    sim = Kernel._get_sim()
    if isnothing(sim.reader)
        sim.reader = Kernel.SessionReader()
    end
    return sim.reader
end
