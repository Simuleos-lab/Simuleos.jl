# WorkSession commit helper (all I2x - explicit SimOs and WorkSession arguments)

function _commit_worksession!(
        simos::Kernel.SimOs,
        worksession::Kernel.WorkSession,
        commit_label::String
    )
    project = Kernel.sim_project(simos)
    storage = project.blobstorage
    tape = Kernel.TapeIO(Kernel.tape_path(project))

    meta = copy(worksession.meta)
    meta["worksession_label"] = worksession.label

    Kernel.commit_stage!(tape, storage, worksession.stage, meta; commit_label=commit_label)
    worksession.stage = Kernel.ScopeStage()
    return nothing
end
