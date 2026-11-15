# Netgen LVS script: compare the extracted layout netlist with the schematic.
# Run with: netgen -batch source lvs/run_lvs.tcl
# Inputs (environment variables set by the Makefile):
#   EXT      extracted netlist file and cell, as "file cell"
#   SCH      schematic netlist file and cell, as "file cell"
#   SETUP    sky130A Netgen setup file from the PDK
#   REPORT   where to write the comparison report

# A MOS transistor's source and drain are interchangeable in the layout,
# so let Netgen swap them when it matches the two circuits.
permute transistors

lvs $::env(EXT) $::env(SCH) $::env(SETUP) $::env(REPORT)
