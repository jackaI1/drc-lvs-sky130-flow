# Magic DRC on one GDS cell, using the full sky130A rule deck from the PDK.
# Inputs (environment variables set by the Makefile):
#   GDS  path to the GDS file
#   CELL name of the cell to check
# Prints every violation with its rule name in parentheses, then a total.

gds read $env(GDS)
load $env(CELL)
drc on
drc check
drc catchup
puts "MAGIC DRC: [drc count total] violation(s) in $env(CELL)"
drc listall why
quit -noprompt
