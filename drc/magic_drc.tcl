# Magic DRC on one GDS cell, using the full sky130A rule deck from the PDK.
# Inputs (environment variables set by the Makefile):
#   GDS  path to the GDS file
#   CELL name of the cell to check
#   MAGIC_RC path to the PDK's sky130A.magicrc (sets the tech, grid and DRC options)
#   PDK_ROOT folder that holds the sky130A PDK
# Prints every violation with its rule name in parentheses. Magic also prints
# "Total DRC errors found: N" for the cell. The "MAGIC DRC:" line marks the run as finished.

source $env(MAGIC_RC)
gds read $env(GDS)
load $env(CELL)
# The sky130 tech file defines the "drc" style in three variants. "full" runs every rule.
drc style drc(full)
drc on
drc check
drc catchup
drc listall why
puts "MAGIC DRC: finished $env(CELL)"
quit -noprompt
