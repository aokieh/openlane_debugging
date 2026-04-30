// //---------------------------------------------------------------------------
// // Module: final_top
// // Description: 
// //  Top-level digital wrapper. Integrates the RegFile, SPI Peripheral, 
// //  and the Dual-Spine DVS Core (fifo_rows_cols_macro).
// //---------------------------------------------------------------------------

// module final_top (
//     `ifdef USE_POWER_PINS
//         inout vccd1, 
//         inout vssd1, 
//     `endif
    
//     input  logic clk,     // sys_clk (50MHz)
//     input  logic rst_n,
//     input  logic pix_rst_global_in, // from digital pin

//     // -----------------------------------------------------------
//     // SPI Interface
//     // -----------------------------------------------------------
//     input  logic       CS_N,
//     // input  logic       SCK,
//     input  logic [3:0] COPI,
//     output logic [3:0] CIPO,
    
//     // -----------------------------------------------------------
//     // Analog / Peripheral Configurations
//     // -----------------------------------------------------------
//     output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
//     output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
//     output logic [`DAC_WIDTH-1:0] dac_config_8, dac_config_9,

//     // -----------------------------------------------------------
//     // DVS Core: Analog Array Interfaces (128x128 Grid)
//     // -----------------------------------------------------------
//     // Top Tier (Quadrants 0 & 1)
//     input  logic [63:0]  array_col_top_left,
//     input  logic [63:0]  array_col_top_right,
//     output logic [63:0]  col_event_rst_top_left,
//     output logic [63:0]  col_event_rst_top_right,
//     output logic [1:0]   detect_pulse_global_top,
//     output logic [1:0]   pre_charge_global_top,
//     output logic [63:0]  row_on_detect_top,
//     output logic [63:0]  row_off_detect_top,

//     // Bottom Tier (Quadrants 2 & 3)
//     input  logic [63:0]  array_col_bot_left,
//     input  logic [63:0]  array_col_bot_right,
//     output logic [63:0]  col_event_rst_bot_left,
//     output logic [63:0]  col_event_rst_bot_right,
//     output logic [1:0]   detect_pulse_global_bot,
//     output logic [1:0]   pre_charge_global_bot,
//     output logic [63:0]  row_on_detect_bot,
//     output logic [63:0]  row_off_detect_bot,

//     // Added for SPI Continuous Read Mode
//     output logic data_ready_top,

//     // TODO: Route these from regfile in the future
//     input  logic         sm_enable,         // Comes from io_pad
    
//     // input  logic [7:0]   program_bits       // set with register

//     output logic pix_rst_global_top_left,
//     output logic pix_rst_global_bot_left,
//     output logic pix_rst_global_top_right,
//     output logic pix_rst_global_bot_right
// );

//     // ---------------------------------------------------
//     // Internal Crossbar Routing
//     // ---------------------------------------------------
//     // SPI <-> RegFile
//     logic                  we_reg;
//     logic                  we_out;
//     logic [`RF_AWIDTH-1:0] addr_reg;
//     logic [ `RF_WIDTH-1:0] wdata_reg;
//     logic [  `RF_MASK-1:0] wmask_reg;
//     logic [ `RF_WIDTH-1:0] rdata_reg;

//     // RegFile <-> Core (IRQs and Metadata)
//     // LINTER FIX: Expanded to 10 bits to match regfile output port expectations
//     logic [9:0]              irq_deassert_thresh_reg;
//     logic [9:0]              irq_assert_thresh_reg;
//     logic                    fifo_rd_en_reg;
//     logic                    fifo_rst_n_reg;
//     logic [7:0]              event_rate_reg;
    
//     logic [13:0] p_pre_charge;
//     logic [13:0] p_buffer;
//     logic [13:0] p_detect;
//     logic [13:0] p_on_detect;
//     logic [13:0] p_off_detect;
//     logic [13:0] p_rst;

//     // SPI <-> Core (FIFO Readout)
//     logic [15:0] rdata_spi_0; // Top Tier
//     logic [15:0] rdata_spi_1; // Bottom Tier
//     logic [1:0]  shift_en_fifo;

//     // Core FIFO Status Flags
//     logic empty_fifo_top, full_fifo_top;
//     logic empty_fifo_bot, full_fifo_bot;
//     logic data_ready_fifo;

//     logic [`FIFO_AWIDTH-1:0] numel_fifo_top;
//     logic [`FIFO_AWIDTH-1:0] numel_fifo_bot;

//     // Aggregate numel for the RegFile (or map them independently)
//     logic [`FIFO_AWIDTH-1:0] fifo_numel_combined;
    
//     assign fifo_numel_combined = numel_fifo_top | numel_fifo_bot; 
//         //metastabilty registers for pixel array reset
//     logic pix_rst_global_m1;
//     logic pix_rst_global_m2;
    
//     // Aggregate the data ready mode (EXACT same gate delays)
//     assign data_ready_fifo = ~empty_fifo_top & ~empty_fifo_bot;
//     assign data_ready_top  = ~empty_fifo_top & ~empty_fifo_bot;

//     // Wires for Internal Buffering - Reset Pixels
//     logic [63:0] col_event_rst_top_left_int;
//     logic [63:0] col_event_rst_top_left_stg1;
//     logic [63:0] col_event_rst_top_right_int;
//     logic [63:0] col_event_rst_top_right_stg1;

//     logic [63:0] col_event_rst_bot_left_int;
//     logic [63:0] col_event_rst_bot_left_stg1;
//     logic [63:0] col_event_rst_bot_right_int;
//     logic [63:0] col_event_rst_bot_right_stg1;

//     // Wires for Internal Buffering - Row On
//     logic [63:0] row_on_detect_top_int;
//     logic [63:0] row_on_detect_top_stg1;
//     logic [63:0] row_on_detect_bot_int;
//     logic [63:0] row_on_detect_bot_stg1;

//     // Wire for Internal Buffering - Row Off
//     logic [63:0] row_off_detect_top_int;
//     logic [63:0] row_off_detect_top_stg1;
//     logic [63:0] row_off_detect_bot_int;
//     logic [63:0] row_off_detect_bot_stg1;
    
//     // Wire for Internal Buffering - Column Pre-Charge
//     logic [1:0] detect_pulse_global_top_int;
//     logic [1:0] detect_pulse_global_top_stg1;
//     logic [1:0] pre_charge_global_top_int;
//     logic [1:0] pre_charge_global_top_stg1;
    
//     logic [1:0] detect_pulse_global_bot_int;
//     logic [1:0] detect_pulse_global_bot_stg1;
//     logic [1:0] pre_charge_global_bot_int;
//     logic [1:0] pre_charge_global_bot_stg1;

//     // Wire for Internal Buffering - Dac Configs
//     logic [`DAC_WIDTH-1:0] dac_config_0_int, dac_config_1_int, dac_config_2_int, dac_config_3_int;
//     logic [`DAC_WIDTH-1:0] dac_config_4_int, dac_config_5_int, dac_config_6_int, dac_config_7_int;
//     logic [`DAC_WIDTH-1:0] dac_config_8_int, dac_config_9_int;

//     logic [`DAC_WIDTH-1:0] dac_config_0_stg1, dac_config_1_stg1, dac_config_2_stg1, dac_config_3_stg1;
//     logic [`DAC_WIDTH-1:0] dac_config_4_stg1, dac_config_5_stg1, dac_config_6_stg1, dac_config_7_stg1;
//     logic [`DAC_WIDTH-1:0] dac_config_8_stg1, dac_config_9_stg1;

//     // Wire for Internal Buffering - Pixel Array Reset
//     logic pix_rst_global_top_left_int;
//     logic pix_rst_global_top_right_int;
//     logic pix_rst_global_bot_left_int;
//     logic pix_rst_global_bot_right_int;

//     logic pix_rst_global_top_left_stg1;
//     logic pix_rst_global_top_right_stg1;
//     logic pix_rst_global_bot_left_stg1;
//     logic pix_rst_global_bot_right_stg1;

//     // ---------------------------------------------------
//     // LINTER FIX: Explicitly Sink All Unused Signals
//     // ---------------------------------------------------
//     wire _unused_signals = &{
//         1'b0,
//         we_out,
//         irq_deassert_thresh_reg,
//         irq_assert_thresh_reg,
//         fifo_rd_en_reg,
//         fifo_rst_n_reg,
//         full_fifo_top,
//         full_fifo_bot
//     };


//     // ---------------------------------------------------
//     // 0. Buffering - Column Event Reset
//     // ---------------------------------------------------
//     // Stage 1: Standard Driver (buf_4) from digital block
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tl [63:0] (
//         .A(col_event_rst_top_left_int),
//         .X(col_event_rst_top_left_stg1)
//     );

//     // Stage 2: Heavy Driver (buf_16) driving the port of analog
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tl [63:0] (
//         .A(col_event_rst_top_left_stg1),
//         .X(col_event_rst_top_left)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tr [63:0] (
//         .A(col_event_rst_top_right_int),
//         .X(col_event_rst_top_right_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tr [63:0] (
//         .A(col_event_rst_top_right_stg1),
//         .X(col_event_rst_top_right)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_bl [63:0] (
//         .A(col_event_rst_bot_left_int),
//         .X(col_event_rst_bot_left_stg1)
//     );

//     // Stage 2: Heavy Driver (buf_16) driving the Port
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_bl [63:0] (
//         .A(col_event_rst_bot_left_stg1),
//         .X(col_event_rst_bot_left)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_br [63:0] (
//         .A(col_event_rst_bot_right_int),
//         .X(col_event_rst_bot_right_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_br [63:0] (
//         .A(col_event_rst_bot_right_stg1),
//         .X(col_event_rst_bot_right)
//     );

//     // ---------------------------------------------------
//     // 0. Buffering - Row On Detect and Row Off Detect
//     // ---------------------------------------------------
//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_top [63:0] (
//         .A(row_on_detect_top_int),
//         .X(row_on_detect_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_top [63:0] (
//         .A(row_on_detect_top_stg1),
//         .X(row_on_detect_top)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_top [63:0] (
//         .A(row_off_detect_top_int),
//         .X(row_off_detect_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_top [63:0] (
//         .A(row_off_detect_top_stg1),
//         .X(row_off_detect_top)
//     );

//             (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_bot [63:0] (
//         .A(row_on_detect_bot_int),
//         .X(row_on_detect_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_bot [63:0] (
//         .A(row_on_detect_bot_stg1),
//         .X(row_on_detect_bot)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_bot [63:0] (
//         .A(row_off_detect_bot_int),
//         .X(row_off_detect_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_bot [63:0] (
//         .A(row_off_detect_bot_stg1),
//         .X(row_off_detect_bot)
//     );

//     // ---------------------------------------------------
//     // 0. Buffering - Detect Pulse and Pre-Charge
//     // ---------------------------------------------------
//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_top [1:0] (
//         .A(detect_pulse_global_top_int),
//         .X(detect_pulse_global_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_top [1:0] (
//         .A(detect_pulse_global_top_stg1),
//         .X(detect_pulse_global_top)
//     );

//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_top [1:0] (
//         .A(pre_charge_global_top_int),
//         .X(pre_charge_global_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_top [1:0] (
//         .A(pre_charge_global_top_stg1),
//         .X(pre_charge_global_top)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_bot [1:0] (
//         .A(detect_pulse_global_bot_int),
//         .X(detect_pulse_global_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_bot [1:0] (
//         .A(detect_pulse_global_bot_stg1),
//         .X(detect_pulse_global_bot)
//     );

//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_bot [1:0] (
//         .A(pre_charge_global_bot_int),
//         .X(pre_charge_global_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_bot [1:0] (
//         .A(pre_charge_global_bot_stg1),
//         .X(pre_charge_global_bot)
//     );
    

//     // ---------------------------------------------------
//     // 1. SPI Peripheral
//     // ---------------------------------------------------
//     spi_peripheral i_spi_peripheral (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
//         .CS_N(CS_N), .SCK(clk), .COPI(COPI), .CIPO(CIPO),
        
//         // Mem I/O
//         .addr_reg, .we_reg, .we_out, .wdata_reg, .wmask_reg, 
//         .rdata_reg,
        
//         // FIFO I/O
//         .rdata_spi_0   (rdata_spi_0),
//         .rdata_spi_1   (rdata_spi_1),
//         .shift_en_fifo (shift_en_fifo),
//         .data_ready_spi(data_ready_fifo) // TODO: added safety for scanning imager
//     );

//     // ---------------------------------------------------
//     // 2. Register File
//     // ---------------------------------------------------
//     regfile i_regfile (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
//         .clk   (clk), 
//         .rst_n (rst_n),

//         // Mem I/O
//         .addr_reg, .we_reg, .wdata_reg, .wmask_reg, .rdata_reg,

//         // FIFO Controls
//         .fifo_rst_n_reg (fifo_rst_n_reg),
//         .fifo_rd_en_reg (fifo_rd_en_reg),
//         .fifo_numel_reg (fifo_numel_combined),

//         // IRQ
//         .irq_deassert_thresh_reg (irq_deassert_thresh_reg),
//         .irq_assert_thresh_reg   (irq_assert_thresh_reg),

//         // Configuration
//         .dac_config_0(dac_config_0_int), .dac_config_1(dac_config_1_int), 
//         .dac_config_2(dac_config_2_int), .dac_config_3(dac_config_3_int), 
//         .dac_config_4(dac_config_4_int), .dac_config_5(dac_config_5_int), 
//         .dac_config_6(dac_config_6_int), .dac_config_7(dac_config_7_int), 
//         .dac_config_8(dac_config_8_int), .dac_config_9(dac_config_9_int),
//         .event_rate_reg, .p_pre_charge, .p_buffer, .p_detect,
//         .p_on_detect(p_on_detect), .p_off_detect, .p_rst
//     );


//     // ---------------------------------------------------
//     // 3. Dual-Spine DVS Core
//     // ---------------------------------------------------
//     fifo_rows_cols_macro2 i_dvs_core (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
        
//         .sys_clk      (clk),
//         .rst_n        (rst_n),
     
//         .sm_enable    (sm_enable),
//         .program_bits (event_rate_reg),
//         .p_pre_charge (p_pre_charge),
//         .p_buffer     (p_buffer),
//         .p_detect     (p_detect),
//         .p_on_detect  (p_on_detect),
//         .p_off_detect (p_off_detect),
//         .p_rst        (p_rst),

//         // Top Tier Analog
//         .array_col_top_left      (array_col_top_left),
//         .array_col_top_right     (array_col_top_right),
//         .col_event_rst_top_left  (col_event_rst_top_left_int),
//         .col_event_rst_top_right (col_event_rst_top_right_int),
//         .detect_pulse_global_top (detect_pulse_global_top_int),
//         .pre_charge_global_top   (pre_charge_global_top_int),
//         .row_on_detect_top       (row_on_detect_top_int),
//         .row_off_detect_top      (row_off_detect_top_int),

//         // Bottom Tier Analog
//         .array_col_bot_left      (array_col_bot_left),
//         .array_col_bot_right     (array_col_bot_right),
//         .col_event_rst_bot_left  (col_event_rst_bot_left_int),
//         .col_event_rst_bot_right (col_event_rst_bot_right_int),
//         .detect_pulse_global_bot (detect_pulse_global_bot_int),
//         .pre_charge_global_bot   (pre_charge_global_bot_int),
//         .row_on_detect_bot       (row_on_detect_bot_int),
//         .row_off_detect_bot      (row_off_detect_bot_int),

//         // Q-SPI Readout Interconnects
//         .shift_en_top   (shift_en_fifo[0]),
//         .rdata_spi_top  (rdata_spi_0),
//         .empty_fifo_top (empty_fifo_top),
//         .full_fifo_top  (full_fifo_top),
//         .numel_fifo_top (numel_fifo_top),

//         .shift_en_bot   (shift_en_fifo[1]),
//         .rdata_spi_bot  (rdata_spi_1),
//         .empty_fifo_bot (empty_fifo_bot),
//         .full_fifo_bot  (full_fifo_bot),
//         .numel_fifo_bot (numel_fifo_bot)
//     );

//         // should global reset have an effect on metastability regs?
//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             pix_rst_global_m1           <= 0;
//             pix_rst_global_m2           <= 0;

//             pix_rst_global_top_left_int     <= 0;
//             pix_rst_global_bot_left_int     <= 0;
//             pix_rst_global_top_right_int    <= 0;
//             pix_rst_global_bot_right_int    <= 0;

//         end else begin
//             // Resolve metastability
//             pix_rst_global_m1  <= pix_rst_global_in;
//             pix_rst_global_m2  <= pix_rst_global_m1;
            
//             pix_rst_global_top_left_int <= pix_rst_global_m2;
//             pix_rst_global_bot_left_int <= pix_rst_global_m2;
//             pix_rst_global_top_right_int <= pix_rst_global_m2;
//             pix_rst_global_bot_right_int <= pix_rst_global_m2;
//         end
//     end

// endmodule : final_top

//---------------------------------------------------------------------------
// Module: final_top
// Description: 
//  Top-level digital wrapper. Integrates the RegFile, SPI Peripheral, 
//  and the Dual-Spine DVS Core (fifo_rows_cols_macro).
//---------------------------------------------------------------------------

// module final_top (
//     `ifdef USE_POWER_PINS
//         inout vccd1, 
//         inout vssd1, 
//     `endif
    
//     input  logic clk,     // sys_clk (50MHz)
//     input  logic rst_n,
//     input  logic pix_rst_global_in, // from digital pin

//     // -----------------------------------------------------------
//     // SPI Interface
//     // -----------------------------------------------------------
//     input  logic       CS_N,
//     // input  logic       SCK,
//     input  logic [3:0] COPI,
//     output logic [3:0] CIPO,
    
//     // -----------------------------------------------------------
//     // Analog / Peripheral Configurations
//     // -----------------------------------------------------------
//     output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
//     output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
//     output logic [`DAC_WIDTH-1:0] dac_config_8, dac_config_9,

//     // -----------------------------------------------------------
//     // DVS Core: Analog Array Interfaces (128x128 Grid)
//     // -----------------------------------------------------------
//     // Top Tier (Quadrants 0 & 1)
//     input  logic [63:0]  array_col_top_left,
//     input  logic [63:0]  array_col_top_right,
//     output logic [63:0]  col_event_rst_top_left,
//     output logic [63:0]  col_event_rst_top_right,
//     output logic [1:0]   detect_pulse_global_top,
//     output logic [1:0]   pre_charge_global_top,
//     output logic [63:0]  row_on_detect_top,
//     output logic [63:0]  row_off_detect_top,

//     // Bottom Tier (Quadrants 2 & 3)
//     input  logic [63:0]  array_col_bot_left,
//     input  logic [63:0]  array_col_bot_right,
//     output logic [63:0]  col_event_rst_bot_left,
//     output logic [63:0]  col_event_rst_bot_right,
//     output logic [1:0]   detect_pulse_global_bot,
//     output logic [1:0]   pre_charge_global_bot,
//     output logic [63:0]  row_on_detect_bot,
//     output logic [63:0]  row_off_detect_bot,

//     // Added for SPI Continuous Read Mode
//     output logic data_ready_top,

//     // TODO: Route these from regfile in the future
//     input  logic         sm_enable,         // Comes from io_pad
    
//     // input  logic [7:0]   program_bits       // set with register

//     output logic pix_rst_global_top_left,
//     output logic pix_rst_global_bot_left,
//     output logic pix_rst_global_top_right,
//     output logic pix_rst_global_bot_right
// );

//     // ---------------------------------------------------
//     // Internal Crossbar Routing
//     // ---------------------------------------------------
//     // SPI <-> RegFile
//     logic                  we_reg;
//     logic                  we_out;
//     logic [`RF_AWIDTH-1:0] addr_reg;
//     logic [ `RF_WIDTH-1:0] wdata_reg;
//     logic [  `RF_MASK-1:0] wmask_reg;
//     logic [ `RF_WIDTH-1:0] rdata_reg;

//     // RegFile <-> Core (IRQs and Metadata)
//     // LINTER FIX: Expanded to 10 bits to match regfile output port expectations
//     logic [9:0]              irq_deassert_thresh_reg;
//     logic [9:0]              irq_assert_thresh_reg;
//     logic                    fifo_rd_en_reg;
//     logic                    fifo_rst_n_reg;
//     logic [7:0]              event_rate_reg;
    
//     logic [13:0] p_pre_charge;
//     logic [13:0] p_buffer;
//     logic [13:0] p_detect;
//     logic [13:0] p_on_detect;
//     logic [13:0] p_off_detect;
//     logic [13:0] p_rst;

//     // SPI <-> Core (FIFO Readout)
//     logic [15:0] rdata_spi_0; // Top Tier
//     logic [15:0] rdata_spi_1; // Bottom Tier
//     logic [1:0]  shift_en_fifo;

//     // Core FIFO Status Flags
//     logic empty_fifo_top, full_fifo_top;
//     logic empty_fifo_bot, full_fifo_bot;
//     logic data_ready_fifo;

//     logic [`FIFO_AWIDTH-1:0] numel_fifo_top;
//     logic [`FIFO_AWIDTH-1:0] numel_fifo_bot;

//     // Aggregate numel for the RegFile (or map them independently)
//     logic [`FIFO_AWIDTH-1:0] fifo_numel_combined;
    
//     assign fifo_numel_combined = numel_fifo_top | numel_fifo_bot; 
//         //metastabilty registers for pixel array reset
//     logic pix_rst_global_m1;
//     logic pix_rst_global_m2;
    
//     // Aggregate the data ready mode (EXACT same gate delays)
//     assign data_ready_fifo = ~empty_fifo_top & ~empty_fifo_bot;
//     assign data_ready_top  = ~empty_fifo_top & ~empty_fifo_bot;

//     // Wires for Internal Buffering - Reset Pixels
//     logic [63:0] col_event_rst_top_left_int;
//     logic [63:0] col_event_rst_top_left_stg1;
//     logic [63:0] col_event_rst_top_right_int;
//     logic [63:0] col_event_rst_top_right_stg1;

//     logic [63:0] col_event_rst_bot_left_int;
//     logic [63:0] col_event_rst_bot_left_stg1;
//     logic [63:0] col_event_rst_bot_right_int;
//     logic [63:0] col_event_rst_bot_right_stg1;

//     // Wires for Internal Buffering - Row On
//     logic [63:0] row_on_detect_top_int;
//     logic [63:0] row_on_detect_top_stg1;
//     logic [63:0] row_on_detect_bot_int;
//     logic [63:0] row_on_detect_bot_stg1;

//     // Wire for Internal Buffering - Row Off
//     logic [63:0] row_off_detect_top_int;
//     logic [63:0] row_off_detect_top_stg1;
//     logic [63:0] row_off_detect_bot_int;
//     logic [63:0] row_off_detect_bot_stg1;
    
//     // Wire for Internal Buffering - Column Pre-Charge & Detect Pulse (FIXED)
//     logic [1:0] detect_pulse_global_top_int;
//     logic [1:0] detect_pulse_global_top_stg1;
//     logic [1:0] pre_charge_global_top_int;
//     logic [1:0] pre_charge_global_top_stg1;
    
//     logic [1:0] detect_pulse_global_bot_int;
//     logic [1:0] detect_pulse_global_bot_stg1;
//     logic [1:0] pre_charge_global_bot_int;
//     logic [1:0] pre_charge_global_bot_stg1;

//     // Wire for Internal Buffering - Dac Configs
//     logic [`DAC_WIDTH-1:0] dac_config_0_int, dac_config_1_int, dac_config_2_int, dac_config_3_int;
//     logic [`DAC_WIDTH-1:0] dac_config_4_int, dac_config_5_int, dac_config_6_int, dac_config_7_int;
//     logic [`DAC_WIDTH-1:0] dac_config_8_int, dac_config_9_int;

//     logic [`DAC_WIDTH-1:0] dac_config_0_stg1, dac_config_1_stg1, dac_config_2_stg1, dac_config_3_stg1;
//     logic [`DAC_WIDTH-1:0] dac_config_4_stg1, dac_config_5_stg1, dac_config_6_stg1, dac_config_7_stg1;
//     logic [`DAC_WIDTH-1:0] dac_config_8_stg1, dac_config_9_stg1;

//     // Wire for Internal Buffering - Pixel Array Reset
//     logic pix_rst_global_top_left_int;
//     logic pix_rst_global_top_right_int;
//     logic pix_rst_global_bot_left_int;
//     logic pix_rst_global_bot_right_int;

//     logic pix_rst_global_top_left_stg1;
//     logic pix_rst_global_top_right_stg1;
//     logic pix_rst_global_bot_left_stg1;
//     logic pix_rst_global_bot_right_stg1;

//     // ---------------------------------------------------
//     // LINTER FIX: Explicitly Sink All Unused Signals
//     // ---------------------------------------------------
//     wire _unused_signals = &{
//         1'b0,
//         we_out,
//         irq_deassert_thresh_reg,
//         irq_assert_thresh_reg,
//         fifo_rd_en_reg,
//         fifo_rst_n_reg,
//         full_fifo_top,
//         full_fifo_bot
//     };


//     // ---------------------------------------------------
//     // 0. Buffering - Column Event Reset
//     // ---------------------------------------------------
//     // Stage 1: Standard Driver (buf_4) from digital block
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tl [63:0] (
//         .A(col_event_rst_top_left_int),
//         .X(col_event_rst_top_left_stg1)
//     );

//     // Stage 2: Heavy Driver (buf_16) driving the port of analog
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tl [63:0] (
//         .A(col_event_rst_top_left_stg1),
//         .X(col_event_rst_top_left)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tr [63:0] (
//         .A(col_event_rst_top_right_int),
//         .X(col_event_rst_top_right_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tr [63:0] (
//         .A(col_event_rst_top_right_stg1),
//         .X(col_event_rst_top_right)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_bl [63:0] (
//         .A(col_event_rst_bot_left_int),
//         .X(col_event_rst_bot_left_stg1)
//     );

//     // Stage 2: Heavy Driver (buf_16) driving the Port
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_bl [63:0] (
//         .A(col_event_rst_bot_left_stg1),
//         .X(col_event_rst_bot_left)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_br [63:0] (
//         .A(col_event_rst_bot_right_int),
//         .X(col_event_rst_bot_right_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_br [63:0] (
//         .A(col_event_rst_bot_right_stg1),
//         .X(col_event_rst_bot_right)
//     );

//     // ---------------------------------------------------
//     // 0. Buffering - Row On Detect and Row Off Detect
//     // ---------------------------------------------------
//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_top [63:0] (
//         .A(row_on_detect_top_int),
//         .X(row_on_detect_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_top [63:0] (
//         .A(row_on_detect_top_stg1),
//         .X(row_on_detect_top)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_top [63:0] (
//         .A(row_off_detect_top_int),
//         .X(row_off_detect_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_top [63:0] (
//         .A(row_off_detect_top_stg1),
//         .X(row_off_detect_top)
//     );

//             (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_bot [63:0] (
//         .A(row_on_detect_bot_int),
//         .X(row_on_detect_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_bot [63:0] (
//         .A(row_on_detect_bot_stg1),
//         .X(row_on_detect_bot)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_bot [63:0] (
//         .A(row_off_detect_bot_int),
//         .X(row_off_detect_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_bot [63:0] (
//         .A(row_off_detect_bot_stg1),
//         .X(row_off_detect_bot)
//     );

//     // ---------------------------------------------------
//     // 0. Buffering - Detect Pulse and Pre-Charge
//     // ---------------------------------------------------
//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_top [1:0] (
//         .A(detect_pulse_global_top_int),
//         .X(detect_pulse_global_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_top [1:0] (
//         .A(detect_pulse_global_top_stg1),
//         .X(detect_pulse_global_top)
//     );

//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_top [1:0] (
//         .A(pre_charge_global_top_int),
//         .X(pre_charge_global_top_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_top [1:0] (
//         .A(pre_charge_global_top_stg1),
//         .X(pre_charge_global_top)
//     );

//         (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_bot [1:0] (
//         .A(detect_pulse_global_bot_int),
//         .X(detect_pulse_global_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_bot [1:0] (
//         .A(detect_pulse_global_bot_stg1),
//         .X(detect_pulse_global_bot)
//     );

//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_bot [1:0] (
//         .A(pre_charge_global_bot_int),
//         .X(pre_charge_global_bot_stg1)
//     );
//     (* keep = "true" *)
//     sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_bot [1:0] (
//         .A(pre_charge_global_bot_stg1),
//         .X(pre_charge_global_bot)
//     );

//     // ---------------------------------------------------
//     // 0. Buffering - DAC Configs (ADDED)
//     // ---------------------------------------------------
//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_0 [`DAC_WIDTH-1:0] (.A(dac_config_0_int), .X(dac_config_0_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_0 [`DAC_WIDTH-1:0] (.A(dac_config_0_stg1), .X(dac_config_0));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_1 [`DAC_WIDTH-1:0] (.A(dac_config_1_int), .X(dac_config_1_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_1 [`DAC_WIDTH-1:0] (.A(dac_config_1_stg1), .X(dac_config_1));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_2 [`DAC_WIDTH-1:0] (.A(dac_config_2_int), .X(dac_config_2_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_2 [`DAC_WIDTH-1:0] (.A(dac_config_2_stg1), .X(dac_config_2));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_3 [`DAC_WIDTH-1:0] (.A(dac_config_3_int), .X(dac_config_3_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_3 [`DAC_WIDTH-1:0] (.A(dac_config_3_stg1), .X(dac_config_3));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_4 [`DAC_WIDTH-1:0] (.A(dac_config_4_int), .X(dac_config_4_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_4 [`DAC_WIDTH-1:0] (.A(dac_config_4_stg1), .X(dac_config_4));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_5 [`DAC_WIDTH-1:0] (.A(dac_config_5_int), .X(dac_config_5_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_5 [`DAC_WIDTH-1:0] (.A(dac_config_5_stg1), .X(dac_config_5));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_6 [`DAC_WIDTH-1:0] (.A(dac_config_6_int), .X(dac_config_6_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_6 [`DAC_WIDTH-1:0] (.A(dac_config_6_stg1), .X(dac_config_6));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_7 [`DAC_WIDTH-1:0] (.A(dac_config_7_int), .X(dac_config_7_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_7 [`DAC_WIDTH-1:0] (.A(dac_config_7_stg1), .X(dac_config_7));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_8 [`DAC_WIDTH-1:0] (.A(dac_config_8_int), .X(dac_config_8_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_8 [`DAC_WIDTH-1:0] (.A(dac_config_8_stg1), .X(dac_config_8));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_9 [`DAC_WIDTH-1:0] (.A(dac_config_9_int), .X(dac_config_9_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_9 [`DAC_WIDTH-1:0] (.A(dac_config_9_stg1), .X(dac_config_9));

//     // ---------------------------------------------------
//     // 0. Buffering - Pixel Array Reset (ADDED)
//     // ---------------------------------------------------
//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_tl (.A(pix_rst_global_top_left_int), .X(pix_rst_global_top_left_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_tl (.A(pix_rst_global_top_left_stg1), .X(pix_rst_global_top_left));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_tr (.A(pix_rst_global_top_right_int), .X(pix_rst_global_top_right_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_tr (.A(pix_rst_global_top_right_stg1), .X(pix_rst_global_top_right));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_bl (.A(pix_rst_global_bot_left_int), .X(pix_rst_global_bot_left_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_bl (.A(pix_rst_global_bot_left_stg1), .X(pix_rst_global_bot_left));

//     (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_br (.A(pix_rst_global_bot_right_int), .X(pix_rst_global_bot_right_stg1));
//     (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_br (.A(pix_rst_global_bot_right_stg1), .X(pix_rst_global_bot_right));


//     // ---------------------------------------------------
//     // 1. SPI Peripheral
//     // ---------------------------------------------------
//     spi_peripheral i_spi_peripheral (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
//         .CS_N(CS_N), .SCK(clk), .COPI(COPI), .CIPO(CIPO),
        
//         // Mem I/O
//         .addr_reg, .we_reg, .we_out, .wdata_reg, .wmask_reg, 
//         .rdata_reg,
        
//         // FIFO I/O
//         .rdata_spi_0   (rdata_spi_0),
//         .rdata_spi_1   (rdata_spi_1),
//         .shift_en_fifo (shift_en_fifo),
//         .data_ready_spi(data_ready_fifo) // TODO: added safety for scanning imager
//     );

//     // ---------------------------------------------------
//     // 2. Register File
//     // ---------------------------------------------------
//     regfile i_regfile (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
//         .clk   (clk), 
//         .rst_n (rst_n),

//         // Mem I/O
//         .addr_reg, .we_reg, .wdata_reg, .wmask_reg, .rdata_reg,

//         // FIFO Controls
//         .fifo_rst_n_reg (fifo_rst_n_reg),
//         .fifo_rd_en_reg (fifo_rd_en_reg),
//         .fifo_numel_reg (fifo_numel_combined),

//         // IRQ
//         .irq_deassert_thresh_reg (irq_deassert_thresh_reg),
//         .irq_assert_thresh_reg   (irq_assert_thresh_reg),

//         // Configuration
//         .dac_config_0(dac_config_0_int), .dac_config_1(dac_config_1_int), 
//         .dac_config_2(dac_config_2_int), .dac_config_3(dac_config_3_int), 
//         .dac_config_4(dac_config_4_int), .dac_config_5(dac_config_5_int), 
//         .dac_config_6(dac_config_6_int), .dac_config_7(dac_config_7_int), 
//         .dac_config_8(dac_config_8_int), .dac_config_9(dac_config_9_int),
//         .event_rate_reg, .p_pre_charge, .p_buffer, .p_detect,
//         .p_on_detect(p_on_detect), .p_off_detect, .p_rst
//     );


//     // ---------------------------------------------------
//     // 3. Dual-Spine DVS Core
//     // ---------------------------------------------------
//     fifo_rows_cols_macro2 i_dvs_core (
//         `ifdef USE_POWER_PINS
//             .vccd1 (vccd1), .vssd1 (vssd1),
//         `endif
        
//         .sys_clk      (clk),
//         .rst_n        (rst_n),
     
//         .sm_enable    (sm_enable),
//         .program_bits (event_rate_reg),
//         .p_pre_charge (p_pre_charge),
//         .p_buffer     (p_buffer),
//         .p_detect     (p_detect),
//         .p_on_detect  (p_on_detect),
//         .p_off_detect (p_off_detect),
//         .p_rst        (p_rst),

//         // Top Tier Analog
//         .array_col_top_left      (array_col_top_left),
//         .array_col_top_right     (array_col_top_right),
//         .col_event_rst_top_left  (col_event_rst_top_left_int),
//         .col_event_rst_top_right (col_event_rst_top_right_int),
//         .detect_pulse_global_top (detect_pulse_global_top_int),
//         .pre_charge_global_top   (pre_charge_global_top_int),
//         .row_on_detect_top       (row_on_detect_top_int),
//         .row_off_detect_top      (row_off_detect_top_int),

//         // Bottom Tier Analog
//         .array_col_bot_left      (array_col_bot_left),
//         .array_col_bot_right     (array_col_bot_right),
//         .col_event_rst_bot_left  (col_event_rst_bot_left_int),
//         .col_event_rst_bot_right (col_event_rst_bot_right_int),
//         .detect_pulse_global_bot (detect_pulse_global_bot_int),
//         .pre_charge_global_bot   (pre_charge_global_bot_int),
//         .row_on_detect_bot       (row_on_detect_bot_int),
//         .row_off_detect_bot      (row_off_detect_bot_int),

//         // Q-SPI Readout Interconnects
//         .shift_en_top   (shift_en_fifo[0]),
//         .rdata_spi_top  (rdata_spi_0),
//         .empty_fifo_top (empty_fifo_top),
//         .full_fifo_top  (full_fifo_top),
//         .numel_fifo_top (numel_fifo_top),

//         .shift_en_bot   (shift_en_fifo[1]),
//         .rdata_spi_bot  (rdata_spi_1),
//         .empty_fifo_bot (empty_fifo_bot),
//         .full_fifo_bot  (full_fifo_bot),
//         .numel_fifo_bot (numel_fifo_bot)
//     );

//         // should global reset have an effect on metastability regs?
//     always_ff @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             pix_rst_global_m1           <= 0;
//             pix_rst_global_m2           <= 0;

//             pix_rst_global_top_left_int     <= 0;
//             pix_rst_global_bot_left_int     <= 0;
//             pix_rst_global_top_right_int    <= 0;
//             pix_rst_global_bot_right_int    <= 0;

//         end else begin
//             // Resolve metastability
//             pix_rst_global_m1  <= pix_rst_global_in;
//             pix_rst_global_m2  <= pix_rst_global_m1;
            
//             pix_rst_global_top_left_int <= pix_rst_global_m2;
//             pix_rst_global_bot_left_int <= pix_rst_global_m2;
//             pix_rst_global_top_right_int <= pix_rst_global_m2;
//             pix_rst_global_bot_right_int <= pix_rst_global_m2;
//         end
//     end

// endmodule : final_top

//---------------------------------------------------------------------------
// Module: final_top
// Description: 
//  Top-level digital wrapper. Integrates the RegFile, SPI Peripheral, 
//  and the Dual-Spine DVS Core (fifo_rows_cols_macro).
//---------------------------------------------------------------------------

// LINTER FIX: Clean macro to inject standard cell power pins dynamically
`ifdef USE_POWER_PINS
    `define SC_PWR_PINS .VPWR(vccd1), .VGND(vssd1), .VPB(vccd1), .VNB(vssd1),
`else
    `define SC_PWR_PINS
`endif

module final_top2 (
    `ifdef USE_POWER_PINS
        inout vccd1, 
        inout vssd1, 
    `endif
    
    input  logic clk,     // sys_clk (50MHz)
    input  logic rst_n,

    // -----------------------------------------------------------
    // SPI Interface
    // -----------------------------------------------------------
    input  logic       CS_N,
    // input  logic       SCK,
    input  logic [3:0] COPI,
    output logic [3:0] CIPO,
    
    // -----------------------------------------------------------
    // Analog / Peripheral Configurations
    // -----------------------------------------------------------
    output logic [`DAC_WIDTH-1:0] dac_config_0, dac_config_1, dac_config_2, dac_config_3,
    output logic [`DAC_WIDTH-1:0] dac_config_4, dac_config_5, dac_config_6, dac_config_7,
    output logic [`DAC_WIDTH-1:0] dac_config_8, dac_config_9,

    // -----------------------------------------------------------
    // DVS Core: Analog Array Interfaces (128x128 Grid)
    // -----------------------------------------------------------
    // Top Tier (Quadrants 0 & 1)
    input  logic [63:0]  array_col_top_left,
    input  logic [63:0]  array_col_top_right,
    output logic [63:0]  col_event_rst_top_left,
    output logic [63:0]  col_event_rst_top_right,
    output logic [1:0]   detect_pulse_global_top,
    output logic [1:0]   pre_charge_global_top,
    output logic [63:0]  row_on_detect_top,
    output logic [63:0]  row_off_detect_top,

    // Bottom Tier (Quadrants 2 & 3)
    input  logic [63:0]  array_col_bot_left,
    input  logic [63:0]  array_col_bot_right,
    output logic [63:0]  col_event_rst_bot_left,
    output logic [63:0]  col_event_rst_bot_right,
    output logic [1:0]   detect_pulse_global_bot,
    output logic [1:0]   pre_charge_global_bot,
    output logic [63:0]  row_on_detect_bot,
    output logic [63:0]  row_off_detect_bot,

    // Added for SPI Continuous Read Mode
    output logic data_ready_top,

    // TODO: Route these from regfile in the future
    input  logic         sm_enable,         // Comes from io_pad
    input  logic pix_rst_global_in,         // from digital pin

    // input  logic [7:0]   program_bits       // set with register

    output logic pix_rst_global_top_left,
    output logic pix_rst_global_bot_left,
    output logic pix_rst_global_top_right,
    output logic pix_rst_global_bot_right
);

    // ---------------------------------------------------
    // Internal Crossbar Routing
    // ---------------------------------------------------
    // SPI <-> RegFile
    logic                  we_reg;
    logic                  we_out;
    logic [`RF_AWIDTH-1:0] addr_reg;
    logic [ `RF_WIDTH-1:0] wdata_reg;
    logic [  `RF_MASK-1:0] wmask_reg;
    logic [ `RF_WIDTH-1:0] rdata_reg;

    // RegFile <-> Core (IRQs and Metadata)
    // LINTER FIX: Expanded to 10 bits to match regfile output port expectations
    logic [9:0]              irq_deassert_thresh_reg;
    logic [9:0]              irq_assert_thresh_reg;
    logic                    fifo_rd_en_reg;
    logic                    fifo_rst_n_reg;
    logic [7:0]              event_rate_reg;
    
    logic [13:0] p_pre_charge;
    logic [13:0] p_buffer;
    logic [13:0] p_detect;
    logic [13:0] p_on_detect;
    logic [13:0] p_off_detect;
    logic [13:0] p_rst;

    // SPI <-> Core (FIFO Readout)
    logic [15:0] rdata_spi_0; // Top Tier
    logic [15:0] rdata_spi_1; // Bottom Tier
    logic [1:0]  shift_en_fifo;

    // Core FIFO Status Flags
    logic empty_fifo_top, full_fifo_top;
    logic empty_fifo_bot, full_fifo_bot;
    logic data_ready_fifo;

    logic [`FIFO_AWIDTH-1:0] numel_fifo_top;
    logic [`FIFO_AWIDTH-1:0] numel_fifo_bot;

    // Aggregate numel for the RegFile (or map them independently)
    logic [`FIFO_AWIDTH-1:0] fifo_numel_combined;
    
    assign fifo_numel_combined = numel_fifo_top | numel_fifo_bot; 
        //metastabilty registers for pixel array reset
    logic pix_rst_global_m1;
    logic pix_rst_global_m2;
    
    // Aggregate the data ready mode (EXACT same gate delays)
    assign data_ready_fifo = ~empty_fifo_top & ~empty_fifo_bot;
    assign data_ready_top  = ~empty_fifo_top & ~empty_fifo_bot;

    // Wires for Internal Buffering - Reset Pixels
    logic [63:0] col_event_rst_top_left_int;
    logic [63:0] col_event_rst_top_left_stg1;
    logic [63:0] col_event_rst_top_right_int;
    logic [63:0] col_event_rst_top_right_stg1;

    logic [63:0] col_event_rst_bot_left_int;
    logic [63:0] col_event_rst_bot_left_stg1;
    logic [63:0] col_event_rst_bot_right_int;
    logic [63:0] col_event_rst_bot_right_stg1;

    // Wires for Internal Buffering - Row On
    logic [63:0] row_on_detect_top_int;
    logic [63:0] row_on_detect_top_stg1;
    logic [63:0] row_on_detect_bot_int;
    logic [63:0] row_on_detect_bot_stg1;

    // Wire for Internal Buffering - Row Off
    logic [63:0] row_off_detect_top_int;
    logic [63:0] row_off_detect_top_stg1;
    logic [63:0] row_off_detect_bot_int;
    logic [63:0] row_off_detect_bot_stg1;
    
    // Wire for Internal Buffering - Column Pre-Charge
    logic [1:0] detect_pulse_global_top_int;
    logic [1:0] detect_pulse_global_top_stg1;
    logic [1:0] pre_charge_global_top_int;
    logic [1:0] pre_charge_global_top_stg1;
    
    logic [1:0] detect_pulse_global_bot_int;
    logic [1:0] detect_pulse_global_bot_stg1;
    logic [1:0] pre_charge_global_bot_int;
    logic [1:0] pre_charge_global_bot_stg1;

    // Wire for Internal Buffering - Dac Configs
    logic [`DAC_WIDTH-1:0] dac_config_0_int, dac_config_1_int, dac_config_2_int, dac_config_3_int;
    logic [`DAC_WIDTH-1:0] dac_config_4_int, dac_config_5_int, dac_config_6_int, dac_config_7_int;
    logic [`DAC_WIDTH-1:0] dac_config_8_int, dac_config_9_int;

    logic [`DAC_WIDTH-1:0] dac_config_0_stg1, dac_config_1_stg1, dac_config_2_stg1, dac_config_3_stg1;
    logic [`DAC_WIDTH-1:0] dac_config_4_stg1, dac_config_5_stg1, dac_config_6_stg1, dac_config_7_stg1;
    logic [`DAC_WIDTH-1:0] dac_config_8_stg1, dac_config_9_stg1;

    // Wire for Internal Buffering - Pixel Array Reset
    logic pix_rst_global_top_left_int;
    logic pix_rst_global_top_right_int;
    logic pix_rst_global_bot_left_int;
    logic pix_rst_global_bot_right_int;

    logic pix_rst_global_top_left_stg1;
    logic pix_rst_global_top_right_stg1;
    logic pix_rst_global_bot_left_stg1;
    logic pix_rst_global_bot_right_stg1;

    // ---------------------------------------------------
    // LINTER FIX: Explicitly Sink All Unused Signals
    // ---------------------------------------------------
    wire _unused_signals = &{
        1'b0,
        we_out,
        irq_deassert_thresh_reg,
        irq_assert_thresh_reg,
        fifo_rd_en_reg,
        fifo_rst_n_reg,
        full_fifo_top,
        full_fifo_bot
    };


    // ---------------------------------------------------
    // 0. Buffering - Column Event Reset
    // ---------------------------------------------------
    // Stage 1: Standard Driver (buf_4) from digital block
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tl [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_top_left_int),
        .X(col_event_rst_top_left_stg1)
    );

    // Stage 2: Heavy Driver (buf_16) driving the port of analog
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tl [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_top_left_stg1),
        .X(col_event_rst_top_left)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_tr [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_top_right_int),
        .X(col_event_rst_top_right_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_tr [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_top_right_stg1),
        .X(col_event_rst_top_right)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_bl [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_bot_left_int),
        .X(col_event_rst_bot_left_stg1)
    );

    // Stage 2: Heavy Driver (buf_16) driving the Port
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_bl [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_bot_left_stg1),
        .X(col_event_rst_bot_left)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_rst_br [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_bot_right_int),
        .X(col_event_rst_bot_right_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_rst_br [63:0] (
        `SC_PWR_PINS
        .A(col_event_rst_bot_right_stg1),
        .X(col_event_rst_bot_right)
    );

    // ---------------------------------------------------
    // 0. Buffering - Row On Detect and Row Off Detect
    // ---------------------------------------------------
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_top [63:0] (
        `SC_PWR_PINS
        .A(row_on_detect_top_int),
        .X(row_on_detect_top_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_top [63:0] (
        `SC_PWR_PINS
        .A(row_on_detect_top_stg1),
        .X(row_on_detect_top)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_top [63:0] (
        `SC_PWR_PINS
        .A(row_off_detect_top_int),
        .X(row_off_detect_top_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_top [63:0] (
        `SC_PWR_PINS
        .A(row_off_detect_top_stg1),
        .X(row_off_detect_top)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_on_bot [63:0] (
        `SC_PWR_PINS
        .A(row_on_detect_bot_int),
        .X(row_on_detect_bot_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_on_bot [63:0] (
        `SC_PWR_PINS
        .A(row_on_detect_bot_stg1),
        .X(row_on_detect_bot)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_col_row_off_bot [63:0] (
        `SC_PWR_PINS
        .A(row_off_detect_bot_int),
        .X(row_off_detect_bot_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_col_row_off_bot [63:0] (
        `SC_PWR_PINS
        .A(row_off_detect_bot_stg1),
        .X(row_off_detect_bot)
    );

    // ---------------------------------------------------
    // 0. Buffering - Detect Pulse and Pre-Charge
    // ---------------------------------------------------
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_top [1:0] (
        `SC_PWR_PINS
        .A(detect_pulse_global_top_int),
        .X(detect_pulse_global_top_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_top [1:0] (
        `SC_PWR_PINS
        .A(detect_pulse_global_top_stg1),
        .X(detect_pulse_global_top)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_top [1:0] (
        `SC_PWR_PINS
        .A(pre_charge_global_top_int),
        .X(pre_charge_global_top_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_top [1:0] (
        `SC_PWR_PINS
        .A(pre_charge_global_top_stg1),
        .X(pre_charge_global_top)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dp_bot [1:0] (
        `SC_PWR_PINS
        .A(detect_pulse_global_bot_int),
        .X(detect_pulse_global_bot_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dp_bot [1:0] (
        `SC_PWR_PINS
        .A(detect_pulse_global_bot_stg1),
        .X(detect_pulse_global_bot)
    );

    (* keep = "true" *)
    sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pc_bot [1:0] (
        `SC_PWR_PINS
        .A(pre_charge_global_bot_int),
        .X(pre_charge_global_bot_stg1)
    );
    (* keep = "true" *)
    sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pc_bot [1:0] (
        `SC_PWR_PINS
        .A(pre_charge_global_bot_stg1),
        .X(pre_charge_global_bot)
    );

    // ---------------------------------------------------
    // 0. Buffering - DAC Configs (ADDED)
    // ---------------------------------------------------
    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_0 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_0_int), .X(dac_config_0_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_0 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_0_stg1), .X(dac_config_0));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_1 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_1_int), .X(dac_config_1_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_1 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_1_stg1), .X(dac_config_1));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_2 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_2_int), .X(dac_config_2_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_2 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_2_stg1), .X(dac_config_2));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_3 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_3_int), .X(dac_config_3_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_3 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_3_stg1), .X(dac_config_3));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_4 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_4_int), .X(dac_config_4_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_4 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_4_stg1), .X(dac_config_4));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_5 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_5_int), .X(dac_config_5_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_5 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_5_stg1), .X(dac_config_5));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_6 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_6_int), .X(dac_config_6_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_6 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_6_stg1), .X(dac_config_6));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_7 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_7_int), .X(dac_config_7_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_7 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_7_stg1), .X(dac_config_7));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_8 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_8_int), .X(dac_config_8_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_8 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_8_stg1), .X(dac_config_8));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_dac_config_9 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_9_int), .X(dac_config_9_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_dac_config_9 [`DAC_WIDTH-1:0] (`SC_PWR_PINS .A(dac_config_9_stg1), .X(dac_config_9));

    // ---------------------------------------------------
    // 0. Buffering - Pixel Array Reset (ADDED)
    // ---------------------------------------------------
    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_tl (`SC_PWR_PINS .A(pix_rst_global_top_left_int), .X(pix_rst_global_top_left_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_tl (`SC_PWR_PINS .A(pix_rst_global_top_left_stg1), .X(pix_rst_global_top_left));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_tr (`SC_PWR_PINS .A(pix_rst_global_top_right_int), .X(pix_rst_global_top_right_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_tr (`SC_PWR_PINS .A(pix_rst_global_top_right_stg1), .X(pix_rst_global_top_right));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_bl (`SC_PWR_PINS .A(pix_rst_global_bot_left_int), .X(pix_rst_global_bot_left_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_bl (`SC_PWR_PINS .A(pix_rst_global_bot_left_stg1), .X(pix_rst_global_bot_left));

    (* keep = "true" *) sky130_fd_sc_hd__buf_4 analog_drvr_stg1_pix_rst_br (`SC_PWR_PINS .A(pix_rst_global_bot_right_int), .X(pix_rst_global_bot_right_stg1));
    (* keep = "true" *) sky130_fd_sc_hd__buf_16 analog_drvr_stg2_pix_rst_br (`SC_PWR_PINS .A(pix_rst_global_bot_right_stg1), .X(pix_rst_global_bot_right));


    // ---------------------------------------------------
    // 1. SPI Peripheral
    // ---------------------------------------------------
    spi_peripheral i_spi_peripheral (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .CS_N(CS_N), .SCK(clk), .COPI(COPI), .CIPO(CIPO),
        
        // Mem I/O
        .addr_reg, .we_reg, .we_out, .wdata_reg, .wmask_reg, 
        .rdata_reg,
        
        // FIFO I/O
        .rdata_spi_0   (rdata_spi_0),
        .rdata_spi_1   (rdata_spi_1),
        .shift_en_fifo (shift_en_fifo),
        .data_ready_spi(data_ready_fifo) // TODO: added safety for scanning imager
    );

    // ---------------------------------------------------
    // 2. Register File
    // ---------------------------------------------------
    regfile i_regfile (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        .clk   (clk), 
        .rst_n (rst_n),

        // Mem I/O
        .addr_reg, .we_reg, .wdata_reg, .wmask_reg, .rdata_reg,

        // FIFO Controls
        .fifo_rst_n_reg (fifo_rst_n_reg),
        .fifo_rd_en_reg (fifo_rd_en_reg),
        .fifo_numel_reg (fifo_numel_combined),

        // IRQ
        .irq_deassert_thresh_reg (irq_deassert_thresh_reg),
        .irq_assert_thresh_reg   (irq_assert_thresh_reg),

        // Configuration
        .dac_config_0(dac_config_0_int), .dac_config_1(dac_config_1_int), 
        .dac_config_2(dac_config_2_int), .dac_config_3(dac_config_3_int), 
        .dac_config_4(dac_config_4_int), .dac_config_5(dac_config_5_int), 
        .dac_config_6(dac_config_6_int), .dac_config_7(dac_config_7_int), 
        .dac_config_8(dac_config_8_int), .dac_config_9(dac_config_9_int),
        .event_rate_reg, .p_pre_charge, .p_buffer, .p_detect,
        .p_on_detect(p_on_detect), .p_off_detect, .p_rst
    );


    // ---------------------------------------------------
    // 3. Dual-Spine DVS Core
    // ---------------------------------------------------
    fifo_rows_cols_macro2 i_dvs_core (
        `ifdef USE_POWER_PINS
            .vccd1 (vccd1), .vssd1 (vssd1),
        `endif
        
        .sys_clk      (clk),
        .rst_n        (rst_n),
     
        .sm_enable    (sm_enable),
        .program_bits (event_rate_reg),
        .p_pre_charge (p_pre_charge),
        .p_buffer     (p_buffer),
        .p_detect     (p_detect),
        .p_on_detect  (p_on_detect),
        .p_off_detect (p_off_detect),
        .p_rst        (p_rst),

        // Top Tier Analog
        .array_col_top_left      (array_col_top_left),
        .array_col_top_right     (array_col_top_right),
        .col_event_rst_top_left  (col_event_rst_top_left_int),
        .col_event_rst_top_right (col_event_rst_top_right_int),
        .detect_pulse_global_top (detect_pulse_global_top_int),
        .pre_charge_global_top   (pre_charge_global_top_int),
        .row_on_detect_top       (row_on_detect_top_int),
        .row_off_detect_top      (row_off_detect_top_int),

        // Bottom Tier Analog
        .array_col_bot_left      (array_col_bot_left),
        .array_col_bot_right     (array_col_bot_right),
        .col_event_rst_bot_left  (col_event_rst_bot_left_int),
        .col_event_rst_bot_right (col_event_rst_bot_right_int),
        .detect_pulse_global_bot (detect_pulse_global_bot_int),
        .pre_charge_global_bot   (pre_charge_global_bot_int),
        .row_on_detect_bot       (row_on_detect_bot_int),
        .row_off_detect_bot      (row_off_detect_bot_int),

        // Q-SPI Readout Interconnects
        .shift_en_top   (shift_en_fifo[0]),
        .rdata_spi_top  (rdata_spi_0),
        .empty_fifo_top (empty_fifo_top),
        .full_fifo_top  (full_fifo_top),
        .numel_fifo_top (numel_fifo_top),

        .shift_en_bot   (shift_en_fifo[1]),
        .rdata_spi_bot  (rdata_spi_1),
        .empty_fifo_bot (empty_fifo_bot),
        .full_fifo_bot  (full_fifo_bot),
        .numel_fifo_bot (numel_fifo_bot)
    );

        // should global reset have an effect on metastability regs?
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_rst_global_m1           <= 0;
            pix_rst_global_m2           <= 0;

            pix_rst_global_top_left_int     <= 0;
            pix_rst_global_bot_left_int     <= 0;
            pix_rst_global_top_right_int    <= 0;
            pix_rst_global_bot_right_int    <= 0;

        end else begin
            // Resolve metastability
            pix_rst_global_m1  <= pix_rst_global_in;
            pix_rst_global_m2  <= pix_rst_global_m1;
            
            pix_rst_global_top_left_int <= pix_rst_global_m2;
            pix_rst_global_bot_left_int <= pix_rst_global_m2;
            pix_rst_global_top_right_int <= pix_rst_global_m2;
            pix_rst_global_bot_right_int <= pix_rst_global_m2;
        end
    end

endmodule : final_top2