# Home driver methods for SimOs (all I2x - explicit SimOs, accesses fields)

"""
    home_init!(simos::SimOs)

I2x — reads settings, writes simos.home, writes disk

Initialize the home directory on `simos`.
- Reads `homePath` setting (defaults to `~/.simuleos`).
- Creates `SimuleosHome`, ensures directories exist on disk.
- Sets `simos.home`.
"""
function home_init!(simos::SimOs)
    home_path = settings(simos, "homePath", home_simuleos_default_path())
    home_path = abspath(home_path)
    home = SimuleosHome(path = home_path)
    init_home!(home)
    simos.home = home
    return nothing
end
