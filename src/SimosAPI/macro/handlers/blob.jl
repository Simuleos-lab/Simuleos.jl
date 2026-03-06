function _simos_blob_meta(mod, src, args)
    _ = mod
    _ = src
    length(args) == 1 || error("@simos blob.meta expects exactly one positional argument (blob ref/hash/key).")
    lookup_expr = args[1]
    return quote
        $(_Krn).blob_metadata($(_Krn)._get_simos(), $(lookup_expr))
    end
end
