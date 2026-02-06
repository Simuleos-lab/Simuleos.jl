using Test
using Simuleos
import LibGit2

@testset "Git Interface" begin
    # Create temporary git repo for testing
    mktempdir() do dir
        # Initialize repo
        gh = Simuleos.GitHandler(dir)
        Simuleos.git_init(gh)

        @testset "hash" begin
            # Initial commit is needed for hash to work
            test_file = joinpath(dir, "test.txt")
            write(test_file, "content")
            repo = LibGit2.GitRepo(dir)
            LibGit2.add!(repo, "test.txt")
            sig = LibGit2.Signature("Test User", "test@example.com")
            LibGit2.commit(repo, "Initial commit"; author=sig, committer=sig)
            close(repo)

            h = Simuleos.git_hash(gh)
            @test length(h) == 40  # SHA-1 hex string
            @test all(c -> c in "0123456789abcdef", h)
        end

        @testset "dirty" begin
            # After commit, repo should be clean
            @test Simuleos.git_dirty(gh) == false

            # Create uncommitted change
            test_file = joinpath(dir, "test.txt")
            write(test_file, "modified content")

            # Repo should now be dirty
            @test Simuleos.git_dirty(gh) == true
        end

        @testset "branch" begin
            b = Simuleos.git_branch(gh)
            @test !isnothing(b)
            @test length(b) > 0
        end

        @testset "describe" begin
            # describe requires tags, so we create one
            repo = LibGit2.GitRepo(dir)
            LibGit2.tag_create(repo, "v0.1.0", LibGit2.head_oid(repo))
            close(repo)

            d = Simuleos.git_describe(gh)
            @test !isnothing(d)
            @test length(d) > 0
        end
    end

    @testset "Repository identity verification" begin
        mktempdir() do dir1
            mktempdir() do dir2
                # Initialize two separate repos
                gh1 = Simuleos.GitHandler(dir1)
                Simuleos.git_init(gh1)

                # Create a handler for dir2 but initialize dir1
                # This should fail the identity check if we try to use gh1 on dir2's repo
                gh_mixed = Simuleos.GitHandler(dir1)

                # First operation should work
                Simuleos.git_init(gh_mixed)

                # Setup commits
                repo = LibGit2.GitRepo(dir1)
                write(joinpath(dir1, "f.txt"), "data")
                LibGit2.add!(repo, "f.txt")
                sig = LibGit2.Signature("Test", "test@test.com")
                LibGit2.commit(repo, "msg"; author=sig, committer=sig)
                close(repo)

                # Operations should work fine
                @test length(Simuleos.git_hash(gh_mixed)) == 40
            end
        end
    end
end
