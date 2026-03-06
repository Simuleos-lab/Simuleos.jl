# ============================================================
# jmespath/parser.jl — Recursive descent parser for JMESPath
#
# Operator precedence (low to high):
#   or-expression       ||
#   and-expression      &&
#   not-expression      !
#   comparator          == != < <= > >=
#   sub-expression      .
#   index/bracket       [ ] [*] [] [?]
#   primary             identifier, literal, *, (, )
# ============================================================

mutable struct JMESParser
    tokens::Vector{Token}
    pos::Int
end

function _peek(p::JMESParser)::Token
    return p.tokens[p.pos]
end

function _advance!(p::JMESParser)::Token
    tok = p.tokens[p.pos]
    p.pos += 1
    return tok
end

function _expect!(p::JMESParser, tt::TokenType)::Token
    tok = _advance!(p)
    tok.type == tt || error("JMESPath parse error: expected $(tt) but got $(tok.type) '$(tok.value)' at position $(tok.pos)")
    return tok
end

function _at(p::JMESParser, tt::TokenType)::Bool
    return _peek(p).type == tt
end

# --- Entry point ---

function _parse_jmespath(input::AbstractString)::JMESNode
    tokens = _tokenize_jmespath(input)
    isempty(tokens) && return JMESIdentity()
    parser = JMESParser(tokens, 1)
    node = _parse_expression(parser)
    _at(parser, TOK_EOF) || error("JMESPath parse error: unexpected token '$(  _peek(parser).value)' at position $(_peek(parser).pos)")
    return node
end

# --- Precedence climbing ---

function _parse_expression(p::JMESParser)::JMESNode
    return _parse_or(p)
end

function _parse_or(p::JMESParser)::JMESNode
    left = _parse_and(p)
    while _at(p, TOK_OR)
        _advance!(p)
        right = _parse_and(p)
        left = JMESOr(left, right)
    end
    return left
end

function _parse_and(p::JMESParser)::JMESNode
    left = _parse_not(p)
    while _at(p, TOK_AND)
        _advance!(p)
        right = _parse_not(p)
        left = JMESAnd(left, right)
    end
    return left
end

function _parse_not(p::JMESParser)::JMESNode
    if _at(p, TOK_NOT)
        _advance!(p)
        expr = _parse_not(p)
        return JMESNot(expr)
    end
    return _parse_comparator(p)
end

function _parse_comparator(p::JMESParser)::JMESNode
    left = _parse_subexpr(p)
    tok = _peek(p)
    op = _comparator_op(tok.type)
    if !isnothing(op)
        _advance!(p)
        right = _parse_subexpr(p)
        return JMESComparison(op, left, right)
    end
    return left
end

function _comparator_op(tt::TokenType)::Union{Symbol, Nothing}
    tt == TOK_EQ && return :eq
    tt == TOK_NE && return :ne
    tt == TOK_LT && return :lt
    tt == TOK_LE && return :le
    tt == TOK_GT && return :gt
    tt == TOK_GE && return :ge
    return nothing
end

function _parse_subexpr(p::JMESParser)::JMESNode
    left = _parse_bracket(p)
    while _at(p, TOK_DOT)
        _advance!(p)
        right = _parse_dot_rhs(p)
        if _is_projection(left)
            # After a projection, dot-access chains as a nested projection
            left = _append_to_projection(left, right)
        else
            left = JMESSubExpr(left, right)
        end
    end
    return left
end

function _parse_dot_rhs(p::JMESParser)::JMESNode
    tok = _peek(p)
    if tok.type == TOK_FIELD || tok.type == TOK_QUOTED_FIELD
        node = _parse_primary(p)
        return _parse_bracket_tail(p, node)
    elseif tok.type == TOK_STAR
        _advance!(p)
        return _wrap_projection(p, JMESWildcard())
    elseif tok.type == TOK_LBRACKET || tok.type == TOK_FILTER || tok.type == TOK_FLATTEN
        return _parse_bracket_specifier(p, JMESIdentity())
    end
    error("JMESPath parse error: expected identifier, '*', or '[' after '.', got '$(tok.value)' at position $(tok.pos)")
end

function _parse_bracket(p::JMESParser)::JMESNode
    left = _parse_primary(p)
    return _parse_bracket_tail(p, left)
end

function _parse_bracket_tail(p::JMESParser, left::JMESNode)::JMESNode
    while _peek(p).type in (TOK_LBRACKET, TOK_FILTER, TOK_FLATTEN)
        left = _parse_bracket_specifier(p, left)
    end
    return left
end

function _parse_bracket_specifier(p::JMESParser, left::JMESNode)::JMESNode
    tok = _peek(p)

    # [? filter ]
    if tok.type == TOK_FILTER
        _advance!(p)
        predicate = _parse_expression(p)
        _expect!(p, TOK_RBRACKET)
        filter = JMESFilter(predicate)
        projected = JMESIndexExpr(left, filter)
        return _wrap_projection(p, projected)
    end

    # [] flatten
    if tok.type == TOK_FLATTEN
        _advance!(p)
        flattened = JMESIndexExpr(left, JMESFlatten())
        return _wrap_projection(p, flattened)
    end

    # [ number ] or [ * ]
    if tok.type == TOK_LBRACKET
        _advance!(p)
        inner = _peek(p)

        # [*]
        if inner.type == TOK_STAR
            _advance!(p)
            _expect!(p, TOK_RBRACKET)
            wc = JMESIndexExpr(left, JMESListWildcard())
            return _wrap_projection(p, wc)
        end

        # [number]
        if inner.type == TOK_NUMBER
            idx_tok = _advance!(p)
            _expect!(p, TOK_RBRACKET)
            idx = parse(Int, idx_tok.value)
            return JMESIndexExpr(left, JMESIndex(idx))
        end

        error("JMESPath parse error: expected number or '*' inside brackets, got '$(inner.value)' at position $(inner.pos)")
    end

    return left
end

"""Wrap a projection source: if followed by `.` or `[`, parse the projected expression."""
function _wrap_projection(p::JMESParser, source::JMESNode)::JMESNode
    tok = _peek(p)
    if tok.type == TOK_DOT
        _advance!(p)
        right = _parse_dot_rhs(p)
        return JMESProjection(source, right)
    elseif tok.type in (TOK_LBRACKET, TOK_FILTER, TOK_FLATTEN)
        right = _parse_bracket_specifier(p, JMESIdentity())
        return JMESProjection(source, right)
    end
    return JMESProjection(source, JMESIdentity())
end

function _parse_primary(p::JMESParser)::JMESNode
    tok = _peek(p)

    # Unquoted field
    if tok.type == TOK_FIELD
        _advance!(p)
        return JMESField(tok.value)
    end

    # Quoted field
    if tok.type == TOK_QUOTED_FIELD
        _advance!(p)
        return JMESField(tok.value)
    end

    # Star (object wildcard at top level)
    if tok.type == TOK_STAR
        _advance!(p)
        return _wrap_projection(p, JMESWildcard())
    end

    # Literal
    if tok.type == TOK_LITERAL
        _advance!(p)
        return JMESLiteral(_parse_literal_value(tok.value))
    end

    # Raw string
    if tok.type == TOK_RAW_STRING
        _advance!(p)
        return JMESRawString(tok.value)
    end

    # Number (can appear at top level in comparisons)
    if tok.type == TOK_NUMBER
        _advance!(p)
        return JMESLiteral(parse(Int, tok.value))
    end

    # Parenthesized expression
    if tok.type == TOK_LPAREN
        _advance!(p)
        expr = _parse_expression(p)
        _expect!(p, TOK_RPAREN)
        return expr
    end

    # Bracket at top level (leading [, [?, [])
    if tok.type in (TOK_LBRACKET, TOK_FILTER, TOK_FLATTEN)
        return _parse_bracket_specifier(p, JMESIdentity())
    end

    error("JMESPath parse error: unexpected token '$(tok.value)' at position $(tok.pos)")
end

"""Check if an AST node is or ends with a projection."""
_is_projection(::JMESNode) = false
_is_projection(::JMESProjection) = true

"""Append a sub-expression to the innermost projection's right side.
Turns `Projection(src, A)` into `Projection(src, SubExpr(A, B))`."""
function _append_to_projection(proj::JMESProjection, right::JMESNode)::JMESProjection
    inner = proj.right
    if inner isa JMESIdentity
        return JMESProjection(proj.left, right)
    elseif _is_projection(inner)
        return JMESProjection(proj.left, _append_to_projection(inner, right))
    else
        return JMESProjection(proj.left, JMESSubExpr(inner, right))
    end
end

function _parse_literal_value(s::AbstractString)
    s = strip(s)
    s == "true" && return true
    s == "false" && return false
    s == "null" && return nothing
    v = tryparse(Int, s)
    !isnothing(v) && return v
    v = tryparse(Float64, s)
    !isnothing(v) && return v
    # JSON string: "..."
    if startswith(s, '"') && endswith(s, '"') && length(s) >= 2
        return s[2:end-1]
    end
    # Bare string fallback
    return s
end
