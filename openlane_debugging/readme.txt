final_top: location for digital design file and macro hardening if that route is pursued

user_project_wrapper: both macro instantiation configs as well as flattened instantiation (broken)

user_project_wrapper_flattened: this is just the flattened digital cells for the design; attempt at determining the source of the PDN errors. This was a success so the issue is likely in the dummy LEF connections to the power mesh.

PDF Contains the main problems I'm currently encountering with instantiating my dummy analog macro and hooking it up to power. There are some pdn scripts that mimic the standard pdn.tcl in OpenRoad (located under scripts folder)
