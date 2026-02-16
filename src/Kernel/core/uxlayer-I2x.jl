# UXLayer settings refresh (all I2x - explicit SimOs integration)

"""
    uxlayer_load_settings!(simos::SimOs)

I2x — reads simos.project, simos.home; updates simos.ux

Load project-local and home-global settings into the UXLayer.
Called at Phase 3 of sim_init!, after home and project are initialized.
Uses update_source! (additive — preserves existing :runtime and :env sources).

Sources added (priority after :env):
- :local  — {projRoot}/.simuleos/settings.json
- :home   — ~/.simuleos/settings.json
"""
function uxlayer_load_settings!(simos::SimOs)
    ux = ux_root(simos)

    # Load project-local settings
    if !isnothing(simos.project)
        local_path = settings_path(simos.project)
        UXLayers.update_source!(ux, :local, _load_settings_json(local_path))
    end

    # Load home-global settings
    if !isnothing(simos.home)
        home_path = settings_path(simos.home)
        UXLayers.update_source!(ux, :home, _load_settings_json(home_path))
    end

    return nothing
end
