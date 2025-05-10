set_global_assignment -entity "xck_generator" -library "lib_xck_generator" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "xck_generator" -library "lib_xck_generator" -name IP_TOOL_VERSION "14.0"
set_global_assignment -entity "xck_generator" -library "lib_xck_generator" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_xck_generator" -name SPD_FILE [file join $::quartus(sip_path) "xck_generator.spd"]

set_global_assignment -library "lib_xck_generator" -name MISC_FILE [file join $::quartus(sip_path) "xck_generator_sim/xck_generator.vo"]
