# Init create a new ScopeTape session
# - TAI/ error if any trace of `sc` work is found
#   - force julia reset

# TAI/ add force init
macro _st_init_logic(lb)
    quote
        let
            println("at.init")
            local _config = ScopeTapes.st_config()
            local _st_rootdir = _config["root.dir"]
            local __NEW_SC = ScopeTapes.ScopeTape(_st_rootdir)
            __NEW_SC.meta["init.timetag"] = ScopeTapes.now();
            # At reading, check ScopeTapes version
            __NEW_SC.meta["init.ScopeTapes.version"] = pkgversion(ScopeTapes);
            ScopeTapes.__ST_LK_FILE = ScopeTapes.SimpleLockFile(
                joinpath(_st_rootdir, "lock.pip")
            )
            ScopeTapes.__ST = __NEW_SC
            ScopeTapes.st_reset_hooks!()
        end
        # init was here
        global ST_INIT_WH = true
        
        # create label
        isempty($(lb)) && error("Passed an empty label on init")
        ScopeTapes.@st_label $(lb)
        
        nothing
    end |> esc
end

macro st_init(lb)
    quote
        # handle ws flag
        if ScopeTapes.@_tryvalue(ST_INIT_WH) === true
            @warn("A previous init call was detected! Trying to reset")
            ScopeTapes.@_st_clear_mod_labels!()
            ScopeTapes.@_st_init_logic($(lb))
        else
            ScopeTapes.@_st_init_logic($(lb))
        end

    end |> esc
end


macro _post_init_check()
    quote
        if ScopeTapes.@_tryvalue(ST_INIT_WH) !== true
            error("@st_init was not called yet!!!")
        end
    end |> esc
end