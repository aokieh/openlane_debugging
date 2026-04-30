# # ==============================================================================
# # spi_peripheral.sdc
# # ==============================================================================

# # ---------------------------------------------------
# # 1. Clock Definition (SCK)
# # ---------------------------------------------------
# set clk_input $::env(CLOCK_PORT)
# create_clock [get_ports $clk_input] -name SCK_CLK -period $::env(CLOCK_PERIOD)
# puts "\[INFO\]: Creating clock {SCK_CLK} for port $clk_input with period: $::env(CLOCK_PERIOD)"

# set_propagated_clock [all_clocks]
# set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [get_clocks {SCK_CLK}]
# set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {SCK_CLK}]

# # ---------------------------------------------------
# # 2. Design Constraints
# # ---------------------------------------------------
# set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
# set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
# set_timing_derate -early [expr {1-$::env(SYNTH_TIMING_DERATE)}]
# set_timing_derate -late [expr {1+$::env(SYNTH_TIMING_DERATE)}]

# # ---------------------------------------------------
# # 3. Input Delays (Assuming 20% of clock period reserved for external routing)
# # ---------------------------------------------------
# set input_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]

# # External SPI Inputs
# set_input_delay $input_delay_value -clock [get_clocks {SCK_CLK}] [get_ports {CS_N COPI[*]}]

# # Internal Data Inputs (From FIFO/Regfile)
# set_input_delay $input_delay_value -clock [get_clocks {SCK_CLK}] [get_ports {rdata_reg[*] rdata_spi_0[*] rdata_spi_1[*] data_ready_spi}]

# # ---------------------------------------------------
# # 4. Output Delays (Assuming 20% of clock period reserved for external capture)
# # ---------------------------------------------------
# set output_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]

# # External SPI Outputs
# set_output_delay $output_delay_value -clock [get_clocks {SCK_CLK}] [get_ports {CIPO[*]}]

# # Internal Data Outputs (To FIFO/Regfile)
# set_output_delay $output_delay_value -clock [get_clocks {SCK_CLK}] [get_ports {addr_reg[*] we_reg we_out wdata_reg[*] wmask_reg[*] shift_en_fifo[*]}]

# # ---------------------------------------------------
# # 5. Output Capacitive Loads - lower for internal signals
# # ---------------------------------------------------
# # Light load for internal macro-to-macro signals (30 fF)
# set_load 0.03 [get_ports {addr_reg[*] we_reg we_out wdata_reg[*] wmask_reg[*] shift_en_fifo[*]}]

# # Heavy load for external signals routing to Caravel Pads (190 fF)
# set_load 0.19 [get_ports {CIPO[*]}]

# # ---------------------------------------------------
# # 6. Asynchronous Exceptions
# # ---------------------------------------------------
# # CS_N acts as an asynchronous reset to your internal counters. 
# # We tell the STA tool not to check setup/hold against the clock for the reset assertion.
# set_false_path -from [get_ports {CS_N}]



# ==============================================================================
# final_top.sdc
# ==============================================================================

# ---------------------------------------------------
# 1. Clock Definition
# ---------------------------------------------------
set clk_input $::env(CLOCK_PORT)
create_clock [get_ports $clk_input] -name sys_clk -period $::env(CLOCK_PERIOD)
puts "\[INFO\]: Creating clock {sys_clk} for port $clk_input with period: $::env(CLOCK_PERIOD)"

set_propagated_clock [all_clocks]
set_clock_uncertainty $::env(SYNTH_CLOCK_UNCERTAINTY) [get_clocks {sys_clk}]
set_clock_transition $::env(SYNTH_CLOCK_TRANSITION) [get_clocks {sys_clk}]

# ---------------------------------------------------
# 2. Design Constraints
# ---------------------------------------------------
set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
set_timing_derate -early [expr {1-$::env(SYNTH_TIMING_DERATE)}]
set_timing_derate -late [expr {1+$::env(SYNTH_TIMING_DERATE)}]

# ---------------------------------------------------
# 3. Input Delays (Assuming 20% of period reserved for routing)
# ---------------------------------------------------
set input_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]

# External / Pad Inputs
# set_input_delay $input_delay_value -clock [get_clocks {sys_clk}] [get_ports {COPI[*] sm_enable}]
set_input_delay $input_delay_value -clock [get_clocks {sys_clk}] [get_ports {COPI[*] sm_enable CS_N rst_n pix_rst_global_in}]

# Internal Analog Array Inputs
set_input_delay $input_delay_value -clock [get_clocks {sys_clk}] [get_ports {array_col_top_* array_col_bot_*}]

# ---------------------------------------------------
# 4. Output Delays (Assuming 20% of period reserved for capture)
# ---------------------------------------------------
set output_delay_value [expr $::env(CLOCK_PERIOD) * 0.2]

# External / Pad Outputs
set_output_delay $output_delay_value -clock [get_clocks {sys_clk}] [get_ports {CIPO[*] data_ready_top}]

# Internal Analog Array Outputs
set_output_delay $output_delay_value -clock [get_clocks {sys_clk}] [get_ports {col_event_rst_* pre_charge_global_* row_* dac_config_*}]
set_output_delay $output_delay_value -clock [get_clocks {sys_clk}] [get_ports {col_event_rst_* pre_charge_global_* row_* dac_config_* detect_pulse_global_* pix_rst_global_top_* pix_rst_global_bot_*}]
# ---------------------------------------------------
# 5. Output Capacitive Loads
# ---------------------------------------------------
# Light load for internal array routing (30 fF)
# set_load 0.03 [get_ports {col_event_rst_* pre_charge_global_* row_* dac_config_*}]

# 5. Output Capacitive Loads
# Heavy load for analog signals routing to Imager Array (150 fF)
set_load 0.15 [get_ports {col_event_rst_* pre_charge_global_* row_* dac_config_* detect_pulse_global_* pix_rst_global_top_* pix_rst_global_bot_*}]
set_load 0.04 [get_ports {CIPO[*] data_ready_top}]

# 6. Input Transitions (Replacing set_driving_cell)
set_input_transition -max 0.38 [get_ports {COPI[*] sm_enable array_col_top_* array_col_bot_*}]



# ---------------------------------------------------
# 6. Input Driving Cells (Fixes Input Slew Violations)
# ---------------------------------------------------
# Assume all inputs are driven by a standard buf_4 from the Caravel wrapper
# set_driving_cell -lib_cell sky130_fd_sc_hd__buf_4 [all_inputs]

# Except the clock, which will be driven by the wrapper's CTS tree
# set_driving_cell -lib_cell sky130_fd_sc_hd__clkbuf_8 [get_ports clk]


# ---------------------------------------------------
# 7. Asynchronous Exceptions
# ---------------------------------------------------
# Do not check setup/hold against the clock for async resets/chip-selects
set_false_path -from [get_ports {CS_N rst_n pix_rst_global_in}]
set_false_path -to [get_ports {pix_rst_global_*}]