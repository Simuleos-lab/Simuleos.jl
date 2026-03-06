# ============================================================
# jmespath/tokenizer.jl — Tokenizer for JMESPath expressions
# ============================================================

@enum TokenType begin
    TOK_FIELD          # unquoted identifier
    TOK_QUOTED_FIELD   # "quoted identifier"
    TOK_NUMBER         # integer literal (inside brackets)
    TOK_DOT            # .
    TOK_STAR           # *
    TOK_LBRACKET       # [
    TOK_RBRACKET       # ]
    TOK_FILTER         # [?
    TOK_FLATTEN        # []
    TOK_LPAREN         # (
    TOK_RPAREN         # )
    TOK_AND            # &&
    TOK_OR             # ||
    TOK_NOT            # !
    TOK_EQ             # ==
    TOK_NE             # !=
    TOK_LT             # <
    TOK_LE             # <=
    TOK_GT             # >
    TOK_GE             # >=
    TOK_LITERAL        # `json-value`
    TOK_RAW_STRING     # 'raw string'
    TOK_EOF
end

struct Token
    type::TokenType
    value::String
    pos::Int
end

function _is_ident_start(c::Char)::Bool
    return isletter(c) || c == '_'
end

function _is_ident_char(c::Char)::Bool
    return isletter(c) || isdigit(c) || c == '_'
end

function _tokenize_jmespath(input::AbstractString)::Vector{Token}
    tokens = Token[]
    i = 1
    n = length(input)

    while i <= n
        c = input[i]

        # Whitespace
        if isspace(c)
            i += 1
            continue
        end

        # Dot
        if c == '.'
            push!(tokens, Token(TOK_DOT, ".", i))
            i += 1
            continue
        end

        # Star
        if c == '*'
            push!(tokens, Token(TOK_STAR, "*", i))
            i += 1
            continue
        end

        # Left bracket: could be [, [], [?, or [number
        if c == '['
            if i + 1 <= n && input[i + 1] == ']'
                push!(tokens, Token(TOK_FLATTEN, "[]", i))
                i += 2
                continue
            elseif i + 1 <= n && input[i + 1] == '?'
                push!(tokens, Token(TOK_FILTER, "[?", i))
                i += 2
                continue
            else
                push!(tokens, Token(TOK_LBRACKET, "[", i))
                i += 1
                continue
            end
        end

        # Right bracket
        if c == ']'
            push!(tokens, Token(TOK_RBRACKET, "]", i))
            i += 1
            continue
        end

        # Parens
        if c == '('
            push!(tokens, Token(TOK_LPAREN, "(", i))
            i += 1
            continue
        end
        if c == ')'
            push!(tokens, Token(TOK_RPAREN, ")", i))
            i += 1
            continue
        end

        # && and ||
        if c == '&' && i + 1 <= n && input[i + 1] == '&'
            push!(tokens, Token(TOK_AND, "&&", i))
            i += 2
            continue
        end
        if c == '|' && i + 1 <= n && input[i + 1] == '|'
            push!(tokens, Token(TOK_OR, "||", i))
            i += 2
            continue
        end

        # Comparators
        if c == '='
            if i + 1 <= n && input[i + 1] == '='
                push!(tokens, Token(TOK_EQ, "==", i))
                i += 2
                continue
            end
            error("JMESPath syntax error at position $i: expected '==' but got '='")
        end
        if c == '!'
            if i + 1 <= n && input[i + 1] == '='
                push!(tokens, Token(TOK_NE, "!=", i))
                i += 2
                continue
            else
                push!(tokens, Token(TOK_NOT, "!", i))
                i += 1
                continue
            end
        end
        if c == '<'
            if i + 1 <= n && input[i + 1] == '='
                push!(tokens, Token(TOK_LE, "<=", i))
                i += 2
            else
                push!(tokens, Token(TOK_LT, "<", i))
                i += 1
            end
            continue
        end
        if c == '>'
            if i + 1 <= n && input[i + 1] == '='
                push!(tokens, Token(TOK_GE, ">=", i))
                i += 2
            else
                push!(tokens, Token(TOK_GT, ">", i))
                i += 1
            end
            continue
        end

        # Quoted identifier: "..."
        if c == '"'
            start = i
            i += 1
            buf = Char[]
            while i <= n
                ch = input[i]
                if ch == '\\'
                    i + 1 <= n || error("JMESPath syntax error: unterminated escape in quoted identifier at position $start")
                    push!(buf, input[i + 1])
                    i += 2
                elseif ch == '"'
                    i += 1
                    break
                else
                    push!(buf, ch)
                    i += 1
                end
                i > n && error("JMESPath syntax error: unterminated quoted identifier at position $start")
            end
            push!(tokens, Token(TOK_QUOTED_FIELD, String(buf), start))
            continue
        end

        # Raw string: '...'
        if c == '\''
            start = i
            i += 1
            buf = Char[]
            while i <= n
                ch = input[i]
                if ch == '\\'
                    if i + 1 <= n && input[i + 1] == '\''
                        push!(buf, '\'')
                        i += 2
                    else
                        push!(buf, '\\')
                        i += 1
                    end
                elseif ch == '\''
                    i += 1
                    break
                else
                    push!(buf, ch)
                    i += 1
                end
                i > n && error("JMESPath syntax error: unterminated raw string at position $start")
            end
            push!(tokens, Token(TOK_RAW_STRING, String(buf), start))
            continue
        end

        # Literal: `...`
        if c == '`'
            start = i
            i += 1
            buf = Char[]
            while i <= n
                ch = input[i]
                if ch == '\\'
                    if i + 1 <= n && input[i + 1] == '`'
                        push!(buf, '`')
                        i += 2
                    else
                        push!(buf, ch)
                        i += 1
                    end
                elseif ch == '`'
                    i += 1
                    break
                else
                    push!(buf, ch)
                    i += 1
                end
                i > n && error("JMESPath syntax error: unterminated literal at position $start")
            end
            push!(tokens, Token(TOK_LITERAL, String(buf), start))
            continue
        end

        # Unquoted identifier
        if _is_ident_start(c)
            start = i
            while i <= n && _is_ident_char(input[i])
                i += 1
            end
            push!(tokens, Token(TOK_FIELD, input[start:i-1], start))
            continue
        end

        # Number (possibly negative, for array indices)
        if isdigit(c) || (c == '-' && i + 1 <= n && isdigit(input[i + 1]))
            start = i
            if c == '-'
                i += 1
            end
            while i <= n && isdigit(input[i])
                i += 1
            end
            push!(tokens, Token(TOK_NUMBER, input[start:i-1], start))
            continue
        end

        error("JMESPath syntax error: unexpected character '$(c)' at position $i")
    end

    push!(tokens, Token(TOK_EOF, "", n + 1))
    return tokens
end
