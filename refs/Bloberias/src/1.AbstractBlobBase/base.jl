## --.-.--..-- - -- - - - -- . . . .. -. - - -- - 
# meta

# To Implement
# _getmeta_I!(ab)::Dict
# _gettemp_I!(ab)::Dict

getmeta(ab::AbstractBlob) = _getmeta_I!(ab)::Dict
gettemp(ab::AbstractBlob) = _gettemp_I!(ab)::Dict

for name in ["meta", "temp"]
    src_pool = [
        """
            function get$(name)(dflt::Function, ab::AbstractBlob, key) 
                _depot = get$(name)(ab)
                get(dflt, _depot, key)
            end
        """, 
        """
            function get$(name)(ab::AbstractBlob, key, dflt) 
                _depot = get$(name)(ab)
                get(_depot, key, dflt)
            end
        """,
        """
            function get$(name)!(dflt::Function, ab::AbstractBlob, key) 
                _depot = get$(name)(ab)
                get!(dflt, _depot, key)
            end
        """,
        """
            function get$(name)!(ab::AbstractBlob, key, dflt) 
                _depot = get$(name)(ab)
                get!(_depot, key, dflt)
            end
        """,
        """
            function set$(name)!(val::Function, ab::AbstractBlob, key) 
                _depot = get$(name)(ab)
                setindex!(_depot, val(), key)
            end
        """,
        """
            function set$(name)!(ab::AbstractBlob, val, key) 
                _depot = get$(name)(ab)
                setindex!(_depot, val, key)
            end
        """
    ]
    for src in src_pool
        Bloberias.eval(Meta.parse(src))
    end
end