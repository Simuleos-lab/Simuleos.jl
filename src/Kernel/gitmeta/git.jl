# ============================================================
# git.jl — Git metadata interface via LibGit2
# ============================================================

import LibGit2

function _verify_repo(gh::GitHandler)
    isdir(gh.root_path) || error("Git path does not exist: $(gh.root_path)")
    return nothing
end

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

function git_init(gh::GitHandler)
    _verify_repo(gh)
    if !isdir(joinpath(gh.root_path, ".git"))
        LibGit2.init(gh.root_path)
    end
    return gh
end

function git_hash(gh::GitHandler)
    try
        return _with_repo(gh) do repo
            oid = LibGit2.head_oid(repo)
            return string(oid)
        end
    catch
        return ""
    end
end

function git_dirty(gh::GitHandler)::Bool
    try
        return _with_repo(gh) do repo
            return LibGit2.isdirty(repo)
        end
    catch
        return false
    end
end

function git_branch(gh::GitHandler)::String
    try
        return _with_repo(gh) do repo
            name = LibGit2.headname(repo)
            isempty(name) && return "HEAD"
            return startswith(name, "refs/heads/") ? name[12:end] : name
        end
    catch
        return "unknown"
    end
end

function git_describe(gh::GitHandler)::String
    try
        cmd = `git -C $(gh.root_path) describe --tags --always`
        return chomp(read(cmd, String))
    catch
        return ""
    end
end

