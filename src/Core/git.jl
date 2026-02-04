# Git interface using LibGit2 (Julia stdlib)
# Provides safe, functional access to git operations

import LibGit2

"""
    _verify_repo(gh::GitHandler)

Internal function to verify repository identity and return a LibGit2.GitRepo object.

Uses LibGit2 to discover the actual repository root from gh.path and compares with
stored gitdir to prevent accidentally operating on wrong repositories.

Returns a LibGit2.GitRepo object (caller responsible for closing).
"""
function _verify_repo(gh::GitHandler)
    repo = LibGit2.GitRepo(gh.path)

    # Get the actual .git directory path from the repo
    actual_gitdir = LibGit2.path(repo)

    # On first call, gh.gitdir is nothing, so we accept this repo
    # On subsequent calls, verify the gitdir matches
    if !isnothing(gh.gitdir) && gh.gitdir != actual_gitdir
        close(repo)
        error("Repository identity check failed: expected .git dir at '$(gh.gitdir)' but found at '$actual_gitdir'")
    end

    return repo
end

"""
    git_hash(gh::GitHandler)

Get the current commit hash (hex string).

Equivalent to: `git rev-parse HEAD`

Returns a 40-character SHA-1 hash string.
Throws LibGit2 exception if operation fails.
"""
function git_hash(gh::GitHandler)::String
    repo = _verify_repo(gh)
    try
        oid = LibGit2.head_oid(repo)
        return string(oid)
    finally
        close(repo)
    end
end

"""
    git_dirty(gh::GitHandler)

Check if repository has uncommitted changes.

Returns `true` if there are uncommitted changes, `false` otherwise.
Throws LibGit2 exception if operation fails.
"""
function git_dirty(gh::GitHandler)::Bool
    repo = _verify_repo(gh)
    try
        return LibGit2.isdirty(repo)
    finally
        close(repo)
    end
end

"""
    git_describe(gh::GitHandler)

Get git describe output for the current commit.

Equivalent to: `git describe`

Returns a description string (e.g., "v1.0-5-gabc1234").
Throws LibGit2 exception if operation fails.
"""
function git_describe(gh::GitHandler)::String
    repo = _verify_repo(gh)
    try
        result = LibGit2.GitDescribeResult(repo)
        return LibGit2.format(result)
    finally
        close(repo)
    end
end

"""
    git_branch(gh::GitHandler)

Get the current branch name.

Equivalent to: `git branch --show-current`

Returns the branch name as a string.
Throws LibGit2 exception if operation fails.
"""
function git_branch(gh::GitHandler)::String
    repo = _verify_repo(gh)
    try
        return LibGit2.headname(repo)
    finally
        close(repo)
    end
end

"""
    git_remote(gh::GitHandler)

Get the URL of the "origin" remote.

Equivalent to: `git remote get-url origin`

Returns the remote URL as a string.
Throws LibGit2 exception if operation fails.
"""
function git_remote(gh::GitHandler)::String
    repo = _verify_repo(gh)
    try
        r = LibGit2.lookup_remote(repo, "origin")
        return LibGit2.url(r)
    finally
        close(repo)
    end
end

"""
    git_init(gh::GitHandler)

Initialize a new git repository at the path stored in the GitHandler.

Equivalent to: `git init`

This is an exception to the repository identity check - it creates a new repository.
Throws LibGit2 exception if operation fails.
"""
function git_init(gh::GitHandler)
    repo = LibGit2.init(gh.path)
    close(repo)
    return nothing
end

# Backward compatibility aliases (deprecated, will be removed)
const hash = git_hash
const dirty = git_dirty
const describe = git_describe
const branch = git_branch
const remote = git_remote
const init = git_init
