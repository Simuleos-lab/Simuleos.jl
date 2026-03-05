# ============================================================
# git.jl — Git metadata interface via LibGit2
# ============================================================

import LibGit2

function _verify_repo(gh::GitHandler)
    isdir(gh.root_path) || error("Git path does not exist: $(gh.root_path)")
    return nothing
end

_git_repo_marker_path(gh::GitHandler)::String = joinpath(gh.root_path, ".git")
_git_repo_marker_exists(gh::GitHandler)::Bool = ispath(_git_repo_marker_path(gh))
_git_nonfatal_error(err)::Bool = err isa LibGit2.GitError

function _with_repo(f::Function, gh::GitHandler)
    _verify_repo(gh)
    repo = LibGit2.GitRepo(gh.root_path)
    try
        return f(repo)
    finally
        close(repo)
    end
end

function _git_handler_for(root_path::String)
    return GitHandler(root_path)
end

function _git_with_default(f::Function, default, gh::GitHandler)
    _verify_repo(gh)
    _git_repo_marker_exists(gh) || return default
    try
        return f()
    catch err
        _git_nonfatal_error(err) || rethrow()
        return default
    end
end

function _git_tag_for_head(repo::LibGit2.GitRepo, head_oid::LibGit2.GitHash)::Union{Nothing, String}
    head_oid_str = string(head_oid)
    for tag in LibGit2.tag_list(repo)
        ref = nothing
        obj = nothing
        try
            ref = LibGit2.GitReference(repo, "refs/tags/$(tag)")
            obj = LibGit2.peel(ref)
            string(LibGit2.GitHash(obj)) == head_oid_str && return String(tag)
        catch err
            err isa LibGit2.GitError || rethrow()
        finally
            !isnothing(obj) && close(obj)
            !isnothing(ref) && close(ref)
        end
    end
    return nothing
end

function git_init(gh::GitHandler)
    _verify_repo(gh)
    if !_git_repo_marker_exists(gh)
        LibGit2.init(gh.root_path)
    end
    return gh
end

function git_hash(gh::GitHandler)
    return _git_with_default("", gh) do
        return _with_repo(gh) do repo
            oid = LibGit2.head_oid(repo)
            return string(oid)
        end
    end
end

function git_dirty(gh::GitHandler)::Bool
    return _git_with_default(false, gh) do
        return _with_repo(gh) do repo
            return LibGit2.isdirty(repo)
        end
    end
end

function git_branch(gh::GitHandler)::String
    return _git_with_default("unknown", gh) do
        return _with_repo(gh) do repo
            name = LibGit2.headname(repo)
            isempty(name) && return "HEAD"
            return startswith(name, "refs/heads/") ? name[12:end] : name
        end
    end
end

function git_describe(gh::GitHandler)::String
    return _git_with_default("", gh) do
        return _with_repo(gh) do repo
            head_oid = LibGit2.head_oid(repo)
            tag = _git_tag_for_head(repo, head_oid)
            !isnothing(tag) && return tag

            head = string(head_oid)
            n = min(12, lastindex(head))
            return head[1:n]
        end
    end
end

function _git_signature_for_commit(repo::LibGit2.GitRepo)::LibGit2.Signature
    try
        return LibGit2.Signature(repo)
    catch err
        _git_nonfatal_error(err) || rethrow()
        return LibGit2.Signature("Simuleos", "simuleos@local")
    end
end

function git_commit_all!(gh::GitHandler, message::AbstractString)::String
    _verify_repo(gh)
    _git_repo_marker_exists(gh) || error("git_commit_all! requires a git repository at `$(gh.root_path)`.")

    msg = strip(String(message))
    isempty(msg) && error("git_commit_all! commit message cannot be empty.")

    return _with_repo(gh) do repo
        # Equivalent to a non-interactive `git add -A`.
        LibGit2.add!(repo, ".")
        LibGit2.update!(repo, ".")

        # Nothing staged after normalization (for example, ignored-only workspace drift).
        LibGit2.isdirty(repo) || return git_hash(gh)

        sig = _git_signature_for_commit(repo)
        oid = LibGit2.commit(repo, msg; author = sig, committer = sig)
        return string(oid)
    end
end
