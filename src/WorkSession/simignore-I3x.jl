"""
    simignore!(rules::Vector)

I3x — via `_get_worksession()` → reads `SIMOS[].worksession`

Set simignore rules for the current session.
"""
function simignore!(rules::Vector{RuleType})
    worksession = _get_worksession()
    set_simignore_rules!(worksession, rules)
end
