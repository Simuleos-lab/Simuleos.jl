function _simos_query(mod, src, kwargs)
    _ = mod
    _ = src
    _simos_validate_kwargs("tapes.query", kwargs,
        (:class, :session, :commit_label, :scope_label, :src_file, :latest, :limit, :where))
    return _simos_emit_runtime_call(
        :($(_Krn).simos_query),
        Any[],
        kwargs;
        keyword_only = true,
    )
end
