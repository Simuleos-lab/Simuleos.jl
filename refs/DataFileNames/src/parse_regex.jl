# # -------------------------------------------------------------------
# const _REGEXS = Dict()
# function _set_regexs!()
#     empty!(_REGEXS)

#     # escape 
#     ESC_SEPS = _hex_escaped_seps()
#     hex_plsep = ESC_SEPS[:PARAMS_LSEP]
#     hex_prsep = ESC_SEPS[:PARAMS_RSEP]
#     hex_elsep = ESC_SEPS[:ELEMT_SEP]
#     hex_psep = ESC_SEPS[:PAIR_SEP]
#     hex_extsep = ESC_SEPS[:EXT_SEP]

#     # inval_chars
#     inval_chars = [hex_plsep, hex_prsep, hex_elsep, hex_psep]
#     val_char_rstr = "[^$(join(inval_chars))]"
#     noextsep_char_rstr = "[^$(join([inval_chars; hex_extsep]))]"

#     # ------------------------------------------------------------
#     # EXT
#     short_ext_rstr = string(
#         "(?<extstr>",
#             "$(hex_extsep)$(noextsep_char_rstr)*\$",
#         ")",
#     )
#     _REGEXS[:SHORT_EXT_SPLIT_REGEX] = Regex(short_ext_rstr)
    
#     long_ext_rstr = string(
#         "$(hex_prsep)", 
#         "(?<extstr>",
#             "(?:$(hex_extsep)$(noextsep_char_rstr)*)*\$",
#         ")",
#     )
#     _REGEXS[:LONG_EXT_SPLIT_REGEX] = Regex(long_ext_rstr)
    
#     # ------------------------------------------------------------
#     # HEAD # IMPORTANT!!! it assumes the extension is being removed
#     head_rstr = string(
#         "^",
#         "(?<headstr>", 
#             "(?:", 
#                 "$(val_char_rstr)+", 
#                 "(?:$(hex_elsep)|\$)", 
#             ")*", 
#         ")", 
#     )
#     _REGEXS[:HEAD_SPLIT_REGEX] = Regex(head_rstr)
    
#     # ------------------------------------------------------------
#      # PARAMS # IMPORTANT!!! it assumes the extension is being removed
#      params_rstr = string(
#         "$(hex_plsep)",
#             "(?<paramstr>", 
#                 "(?:$(val_char_rstr)+$(hex_psep)$(val_char_rstr)+$(hex_elsep)?)+",
#             ")",
#         "$(hex_prsep)", 
#         "\$"
#     )
#     _REGEXS[:PARAMS_SPLIT_REGEX] = Regex(params_rstr)

#     return _REGEXS
# end

# # -------------------------------------------------------------------
# _get(m, gk::Symbol) = haskey(m, gk) ? m[gk] : ""
# _get(m::Nothing, gk::Symbol) = ""

# # -------------------------------------------------------------------
# function _parse_regex(fname::String)
#     _check__SEPS()
    
#     # remove ext
#     # try long
#     ext_r = _REGEXS[:LONG_EXT_SPLIT_REGEX]
#     m = match(ext_r, fname)
#     extstr = _get(m, :extstr)
#     if isempty(extstr)
#         # try short
#         ext_r = _REGEXS[:SHORT_EXT_SPLIT_REGEX]
#         m = match(ext_r, fname)
#         extstr = _get(m, :extstr)
#     end
#     replace_r = Regex("$(extstr)\$")
#     fname = replace(fname, replace_r => "")
#     @show fname
    
#     # remove head
#     head_r = _REGEXS[:HEAD_SPLIT_REGEX]
#     m = match(head_r, fname)
#     headstr = _get(m, :headstr)
#     @show headstr
#     fname = replace(fname, head_r => "")
#     @show fname
    
#     # remove param body
#     param_r = _REGEXS[:PARAMS_SPLIT_REGEX]
#     m = match(param_r, fname)
#     paramsstr = _get(m, :paramstr)
#     fname = replace(fname, param_r => "")
    
#     digest = fname
#     return (;headstr, paramsstr, extstr, digest)
# end

