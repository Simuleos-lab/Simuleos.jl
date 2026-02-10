"""
    simignore!(rules::Vector)

I3x — via `_get_recorder()` → reads `SIMOS[].recorder`

Set simignore rules for the current session.
"""
function simignore!(rules::Vector{RuleType})
    recorder = _get_recorder()
    set_simignore_rules!(recorder, rules)
end
