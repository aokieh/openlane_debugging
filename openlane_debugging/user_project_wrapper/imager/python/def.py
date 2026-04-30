import math

# ========================================================================
# 1. MACRO DIMENSIONS & CORE PARAMETERS
# ========================================================================
macro_name = "Imager_Top"
pixel_array_size = 1536.0     # The central active area (128 pixels * 12um)
periphery_y = 25.0            # Top/Bottom margins for column periphery
macro_width = 1536.0 + 10     # added space for power rails on edge
macro_height = pixel_array_size + (2 * periphery_y) + 10 # Total: 1586.0 + 10.0, power rails

pin_width   = 0.6
pin_length  = 4.0
DBU         = 1000            # Database units per micron (DEF standard)

# ========================================================================
# 2. SPACING RULES (12um PIXEL PITCH)
# ========================================================================
pixel_pitch = 12.0
offset_1 = 3.0  # 3um inside the pixel boundary
offset_2 = 9.0  # 3um from the other pixel boundary

# Right Edge (DACs)
intra_dac_spacing = 4.0  # Spacing between bits [0:10] inside a single DAC bus
total_dac_height = (10 * (11 * intra_dac_spacing)) 
inter_dac_spacing = (pixel_array_size - total_dac_height) / 10.0 

# ========================================================================
# 3. ROUTING TRACK SNAPPING ENGINE
# ========================================================================
TRACK_X_PITCH, TRACK_X_OFFSET = 0.68, 0.34 # met3 (Vertical) tracks
TRACK_Y_PITCH, TRACK_Y_OFFSET = 0.92, 0.46 # met4 (Horizontal) tracks

def snap_x(val):
    n = round((val - TRACK_X_OFFSET) / TRACK_X_PITCH)
    return (n * TRACK_X_PITCH) + TRACK_X_OFFSET

def snap_y(val):
    n = round((val - TRACK_Y_OFFSET) / TRACK_Y_PITCH)
    return (n * TRACK_Y_PITCH) + TRACK_Y_OFFSET

def get_def_pin(pin_name, edge, ideal_pos, direction, layer):
    """Calculates DEF coordinates relative to the pin center and returns the DEF string."""
    if edge in ["left", "right"]:
        center_y = snap_y(ideal_pos)
        center_x = (pin_length / 2.0) if edge == "left" else (macro_width - (pin_length / 2.0))
        dx, dy = pin_length / 2.0, pin_width / 2.0
    else: # top or bottom
        center_x = snap_x(ideal_pos)
        center_y = (pin_length / 2.0) if edge == "bottom" else (macro_height - (pin_length / 2.0))
        dx, dy = pin_width / 2.0, pin_length / 2.0
        
    # Convert to DBU
    cx_dbu = int(round(center_x * DBU))
    cy_dbu = int(round(center_y * DBU))
    x1_dbu = int(round(-dx * DBU))
    y1_dbu = int(round(-dy * DBU))
    x2_dbu = int(round(dx * DBU))
    y2_dbu = int(round(dy * DBU))
    
    # Format DEF pin block
    lines = [
        f"- {pin_name} + NET {pin_name} + DIRECTION {direction} + USE SIGNAL",
        f"  + PORT",
        f"    + LAYER {layer} ( {x1_dbu} {y1_dbu} ) ( {x2_dbu} {y2_dbu} )",
        f"    + PLACED ( {cx_dbu} {cy_dbu} ) N ;"
    ]
    return "\n".join(lines) + "\n"

# ========================================================================
# 4. PIN COLLECTION
# ========================================================================
def_pins = []

# LEFT EDGE (WEST)
for i in range(128):
    pixel_base_y = periphery_y + (i * pixel_pitch) 
    suffix = "bot" if i < 64 else "top"
    idx = (63 - i) if i < 64 else (127 - i)
        
    def_pins.append(get_def_pin(f"row_on_detect_{suffix}[{idx}]", "left", pixel_base_y + offset_1, "INPUT", "met3"))
    def_pins.append(get_def_pin(f"row_off_detect_{suffix}[{idx}]", "left", pixel_base_y + offset_2, "INPUT", "met3"))

# TOP & BOTTOM EDGES (NORTH/SOUTH)
for i in range(128):
    pixel_base_x = i * pixel_pitch 
    suffix = "left" if i < 64 else "right"
    idx = i if i < 64 else (i - 64)
        
    def_pins.append(get_def_pin(f"array_col_bot_{suffix}[{idx}]", "bottom", pixel_base_x + offset_1, "OUTPUT", "met4"))
    def_pins.append(get_def_pin(f"col_event_rst_bot_{suffix}[{idx}]", "bottom", pixel_base_x + offset_2, "INPUT", "met4"))
    def_pins.append(get_def_pin(f"array_col_top_{suffix}[{idx}]", "top", pixel_base_x + offset_1, "OUTPUT", "met4"))
    def_pins.append(get_def_pin(f"col_event_rst_top_{suffix}[{idx}]", "top", pixel_base_x + offset_2, "INPUT", "met4"))

# RIGHT EDGE (EAST)
current_y = periphery_y + (inter_dac_spacing / 2.0)
for d in range(10): 
    for bit in range(11):
        def_pins.append(get_def_pin(f"dac_config_{d}[{bit}]", "right", current_y, "INPUT", "met3"))
        current_y += intra_dac_spacing
    current_y += inter_dac_spacing 

# CORNER GLOBAL PINS
globals_list = ["pre_charge_global", "detect_pulse_global", "pix_rst_global"]
bot_y_offsets = [9.5, 12.5, 15.5]
top_y_offsets = [(macro_height - periphery_y) + 9.5, 
                 (macro_height - periphery_y) + 12.5, 
                 (macro_height - periphery_y) + 15.5]

for i, sig in enumerate(globals_list):
    def_pins.append(get_def_pin(f"{sig}_bot_left", "left", bot_y_offsets[i], "INPUT", "met3"))
    def_pins.append(get_def_pin(f"{sig}_top_left", "left", top_y_offsets[i], "INPUT", "met3"))
    def_pins.append(get_def_pin(f"{sig}_bot_right", "right", bot_y_offsets[i], "INPUT", "met3"))
    def_pins.append(get_def_pin(f"{sig}_top_right", "right", top_y_offsets[i], "INPUT", "met3"))

# ========================================================================
# 5. DEF FILE WRITE-OUT
# ========================================================================
with open(f"{macro_name}.def", "w") as f:
    f.write(f"VERSION 5.8 ;\nDIVIDERCHAR \"/\" ;\nBUSBITCHARS \"[]\" ;\nDESIGN {macro_name} ;\nUNITS DISTANCE MICRONS {DBU} ;\n\n")
    f.write(f"DIEAREA ( 0 0 ) ( {int(macro_width * DBU)} {int(macro_height * DBU)} ) ;\n\n")
    
    f.write(f"PINS {len(def_pins)} ;\n")
    for p in def_pins:
        f.write(p)
    f.write("END PINS\n\n")
    f.write("END DESIGN\n")

print(f"Successfully generated {macro_name}.def with {len(def_pins)} pins.")