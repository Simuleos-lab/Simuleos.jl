# ScopeReader module - Project-driven scope reading workflow owner

module ScopeReader

import ..Kernel

function project(path::String)::Kernel.SimuleosProject
    return Kernel.resolve_project(path)
end

function _active_session_id_for_project(
        project_driver::Kernel.SimuleosProject
    )::Base.UUID
    sim = Kernel._get_sim()
    ws = sim.worksession
    isnothing(ws) && error("No active session. Pass `session=...` explicitly.")
    active_project = Kernel.sim_project(sim)
    if active_project.simuleos_dir != project_driver.simuleos_dir
        error("Active session belongs to a different project. Pass `session=...` explicitly.")
    end
    return ws.session_id
end

function _resolve_session_id(
        project_driver::Kernel.SimuleosProject,
        session::Union{Symbol, Base.UUID, String}
    )::Base.UUID
    if session === :active
        return _active_session_id_for_project(project_driver)
    end
    if session isa Base.UUID
        return Kernel.resolve_session_id(project_driver, session)
    end
    return Kernel.resolve_session_id(project_driver, session)
end

function each_commits(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active
    )
    session_id = _resolve_session_id(project_driver, session)
    tape = Kernel.TapeIO(Kernel.tape_path(project_driver, session_id))
    return Kernel.iterate_tape(tape)
end

function each_scopes(
        project_driver::Kernel.SimuleosProject;
        session::Union{Symbol, Base.UUID, String} = :active
    )
    return (
        scope
        for commit in each_commits(project_driver; session=session)
        for scope in commit.scopes
    )
end

value(var::Kernel.InlineScopeVariable, project_driver::Kernel.SimuleosProject) = var.value
value(var::Kernel.BlobScopeVariable, project_driver::Kernel.SimuleosProject) = Kernel.blob_read(project_driver.blobstorage, var.blob_ref)
value(var::Kernel.VoidScopeVariable, project_driver::Kernel.SimuleosProject) = nothing

# AGENT: IMPORTANT
# DO NOT ADD EXPORT STATEMENTS

end # module ScopeReader
