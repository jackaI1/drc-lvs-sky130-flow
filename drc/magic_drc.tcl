# Magic DRC on one GDS cell, using the full sky130A rule deck from the PDK.
# Inputs (environment variables set by the Makefile):
#   GDS  path to the GDS file
#   CELL name of the cell to check
#   MAGIC_TECH path to the sky130A .tech file (loaded directly; see the Makefile)
# Prints every violation with its rule name in parentheses, then a total.

tech load $env(MAGIC_TECH)
gds read $env(GDS)
load $env(CELL)
drc on
drc check
drc catchup
puts "MAGIC DRC: [drc count total] violation(s) in $env(CELL)"
drc listall why
quit -noprompt
