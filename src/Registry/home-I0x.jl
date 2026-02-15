# Simuleos home directory methods exposed through Registry.

init_home!(home::Kernel.SimuleosHome)::Kernel.SimuleosHome = Kernel.init_home!(home)
home_path(home::Kernel.SimuleosHome)::String = Kernel.home_path(home)
registry_path(home::Kernel.SimuleosHome)::String = Kernel.registry_path(home)
config_path(home::Kernel.SimuleosHome)::String = Kernel.config_path(home)
