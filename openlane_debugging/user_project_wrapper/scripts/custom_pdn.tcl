# ==============================================================================
# Custom PDN Configuration (Trusting the LEF Obstructions)
# ==============================================================================

# 1. Logical-to-physical power mappings
add_global_connection -net vccd1 -inst_pattern .* -pin_pattern \^VDD$ -power
add_global_connection -net vssd1 -inst_pattern .* -pin_pattern \^VSS$ -ground

add_global_connection -net vdda1 -inst_pattern analog_imager_inst -pin_pattern vdda1 -power
add_global_connection -net vssa1 -inst_pattern analog_imager_inst -pin_pattern vssa1 -ground

set_voltage_domain -name CORE -power vccd1 -ground vssd1

# ------------------------------------------------------------------------------
# 2. Digital Standard Cell Grid (vccd1 / vssd1)
# ------------------------------------------------------------------------------
define_pdn_grid -name stdcell_grid -starts_with POWER -voltage_domain CORE -pins {met4 met5}
add_pdn_stripe -grid stdcell_grid -layer met4 -width 1.6 -pitch 27.14 -offset 13.57 -starts_with POWER -nets {vccd1 vssd1}
add_pdn_stripe -grid stdcell_grid -layer met5 -width 1.6 -pitch 27.14 -offset 13.57 -starts_with POWER -nets {vccd1 vssd1}
add_pdn_connect -grid stdcell_grid -layers {met1 met4}
add_pdn_connect -grid stdcell_grid -layers {met4 met5}

# ------------------------------------------------------------------------------
# 3. Analog Imager Hooks (vdda1 / vssa1)
# ------------------------------------------------------------------------------
define_pdn_grid -name analog_macro_grid -macro -instances analog_imager_inst

# Draw horizontal met5 straps to link the macro's exposed met5 pins to the wrapper boundary.
# The LEF's OBS block will automatically prevent these from routing *through* the core.
add_pdn_stripe -grid analog_macro_grid -layer met5 -width 3.0 -pitch 40.0 -offset 20.0 -nets {vdda1 vssa1} -extend_to_boundary

# Connect the extended met5 straps to the macro's internal met4 vertical pins at the corners
add_pdn_connect -grid analog_macro_grid -layers {met4 met5}