# `.simignore` Feature Design - Decisions

**Topic**: Implement variable filtering for Simuleos via simignore rules (like .gitignore, but for variables)

**Status**: Design Complete - Ready for Implementation

---

## Decision Summary

Create an in-memory rule-based system for filtering variables during capture. Rules are stored in the `Session` struct and can filter both globals and locals by regex pattern, with optional scope targeting.

---

## Questions & Answers

**Q**: What should be ignored?
**A**: Both global and local variables. Rules can be:
- Global (apply to all scopes)
- Per-scope (target specific scope by label)
- Last matching rule determines whether variable is included/excluded

**Q**: Where should ignore patterns be defined?
**A**: In memory, stored in `Session.simignore_rules`. No `.simignore` file; rules are set programmatically via public API.

**Q**: What pattern syntax?
**A**: Regex patterns only. Each rule is a dictionary with:
- `:regex` (required) - `Regex` object for matching variable names
- `:scope` (optional) - scope label string; if missing, rule applies to all scopes
- `:action` (required) - `:include` or `:exclude`

**Q**: Scope parameter availability?
**A**: Pass scope label to `_should_ignore()`. Available from `@sim_capture` macro and scope context.

**Q**: Rule storage location?
**A**: Add `simignore_rules::Vector{Dict{Symbol, Any}}` field to `Session` struct.

**Q**: Filtering for both locals and globals?
**A**: Yes. Apply same filtering in both:
- Globals: line 162 in macros.jl (already has integration point)
- Locals: in `_process_scope!()` during variable processing

**Q**: Rule validation?
**A**:
- `:regex` is required; error if missing or invalid
- `:scope` is optional; if missing, rule applies to all scopes
- `:action` is required; error if missing
- Validate on `set_simignore_rules!()` call, not per-variable

**Q**: Public API design?
**A**: `simignore!(rules::Vector{Dict})` - operates on current session via `_get_session()`. Simple one-shot setter.

---

## Implementation Scope

### New/Modified Files

1. **src/types.jl** - Add `simignore_rules` field to `Session`
2. **src/simignore.jl** - Implement:
   - `set_simignore_rules!(session, rules)` - validate & store rules
   - `simignore!(rules)` - wrapper around current session (public API)
   - Update `_should_ignore(session, name, val, scope_label)` - implement matching logic
3. **src/macros.jl** - Update calls:
   - Pass scope label to `_should_ignore()` in globals capture (line 162)
   - Apply filtering to locals in `_process_scope!()` (line 57)
4. **test/simignore_tests.jl** (new) - Test:
   - Rule validation
   - Global pattern matching
   - Scope-specific pattern matching
   - Action precedence (last rule wins)

### API Examples

```julia
# Set global ignore rule (applies to all scopes)
simignore!([
    Dict(:regex => r"^_", :action => :exclude)  # Ignore private vars
])

# Set scope-specific rule
simignore!([
    Dict(:regex => r"temp", :scope => "setup", :action => :exclude),
    Dict(:regex => r"result", :scope => "analysis", :action => :include)
])

# Mixed: first exclude all _temp, but include _temp_keep
simignore!([
    Dict(:regex => r"^_temp", :action => :exclude),
    Dict(:regex => r"^_temp_keep", :action => :include)
])
```

### Matching Logic

```
For each variable (name, value, scope_label):

  Step 1: Type-based filtering (always applied)
    - if value isa Module || value isa Function
      return true (ignore - don't capture)

  Step 2: Rule-based filtering (simignore rules)
    matching_rules = filter rules where:
      - regex matches name AND
      - scope is missing OR scope == scope_label

    if no matching rules:
      return false (don't ignore, include variable by default)
    else:
      last_action = action of last matching rule
      return last_action == :exclude
```

**Default behavior**: Variables are INCLUDED unless explicitly excluded by a matching rule.

---

## Next Steps

1. Implement and test (detailed plan on request)
2. Verify integration with `@sim_capture` and `@sim_store`
3. Add documentation to README
