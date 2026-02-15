const TEST_ROOT_PATH = Ref{Union{Nothing, String}}(nothing)
const TEST_PROJECT_PATH = Ref{Union{Nothing, String}}(nothing)
const TEST_HOME_PATH = Ref{Union{Nothing, String}}(nothing)
const TEST_PREV_CWD = Ref{Union{Nothing, String}}(nothing)

function _require_test_init!()
    isnothing(TEST_PROJECT_PATH[]) && error("Test context not initialized. Call test_init!() first.")
    isnothing(TEST_HOME_PATH[]) && error("Test context not initialized. Call test_init!() first.")
    return nothing
end

test_project_path()::String = (isnothing(TEST_PROJECT_PATH[]) ? error("Test context not initialized.") : TEST_PROJECT_PATH[])
test_home_path()::String = (isnothing(TEST_HOME_PATH[]) ? error("Test context not initialized.") : TEST_HOME_PATH[])

function test_init!()
    if !isnothing(TEST_ROOT_PATH[])
        test_cleanup!()
    end

    kernel = Simuleos.Kernel
    kernel.reset_sim!()

    root_path = mktempdir()
    project_path = joinpath(root_path, "project")
    home_path = joinpath(root_path, "home")
    mkpath(project_path)

    TEST_PREV_CWD[] = pwd()
    TEST_ROOT_PATH[] = root_path
    TEST_PROJECT_PATH[] = project_path
    TEST_HOME_PATH[] = home_path

    cd(project_path)
    kernel.sim_init(
        project_path;
        bootstrap = Dict{String, Any}("homePath" => home_path)
    )

    return nothing
end

function test_cleanup!()
    kernel = Simuleos.Kernel
    kernel.reset_sim!()

    if !isnothing(TEST_PREV_CWD[])
        cd(TEST_PREV_CWD[])
    end

    if !isnothing(TEST_ROOT_PATH[])
        rm(TEST_ROOT_PATH[]; recursive=true, force=true)
    end

    TEST_PREV_CWD[] = nothing
    TEST_ROOT_PATH[] = nothing
    TEST_PROJECT_PATH[] = nothing
    TEST_HOME_PATH[] = nothing
    return nothing
end

function with_test_context(f::Function)
    _require_test_init!()

    kernel = Simuleos.Kernel
    main_project_path = test_project_path()
    main_home_path = test_home_path()
    caller_cwd = pwd()

    temp_root_path = mktempdir()
    temp_project_path = joinpath(temp_root_path, "project")
    temp_home_path = joinpath(temp_root_path, "home")
    mkpath(temp_project_path)

    kernel.reset_sim!()
    cd(temp_project_path)
    kernel.sim_init(
        temp_project_path;
        bootstrap = Dict{String, Any}("homePath" => temp_home_path)
    )

    ctx = Dict{Symbol, String}(
        :root_path => temp_root_path,
        :project_path => temp_project_path,
        :home_path => temp_home_path
    )

    try
        return f(ctx)
    finally
        kernel.reset_sim!()
        cd(main_project_path)
        kernel.sim_init(
            main_project_path;
            bootstrap = Dict{String, Any}("homePath" => main_home_path)
        )
        rm(temp_root_path; recursive=true, force=true)
        cd(caller_cwd)
    end
end
