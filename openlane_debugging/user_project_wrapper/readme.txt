config_macros.json:
contains configurations for making macro of digital block and analog design from dummy LEF/GDS. This approach works with the designs residing on separate power rails (vccd1/vdda1).

config.json:
contains configurations for making an analog macro instance within the flattened top level wrapper. This approach breaks due to PDN warnings and violations

source for configs (OpenLane 1):
https://docs.google.com/document/d/1pf-wbpgjeNEM-1TcvX2OJTkHjqH_C9p-LURCASS0Zo8/edit?tab=t.0
