# WorkSession commit helper (all I2x - explicit SimOs and WorkSession arguments)

function _commit_worksession!(
        simos::Kernel.SimOs,
        worksession::Kernel.WorkSession,
        commit_label::String
    )
    project = Kernel.sim_project(simos)

    # Ensure session scopetapes directory exists
    scopetapes = Kernel._scopetapes_dir(project.simuleos_dir, worksession.session_id)
    mkpath(scopetapes)

    tape = Kernel.TapeIO(Kernel.tape_path(project, worksession.session_id))

    meta = copy(worksession.meta)
    meta["session_id"] = string(worksession.session_id)
    meta["session_labels"] = worksession.labels

    Kernel.commit_stage!(tape, worksession.stage, meta; commit_label=commit_label)
    worksession.stage = Kernel.ScopeStage()
    return nothing
end
