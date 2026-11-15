# Magic DRC on one GDS cell, using the full sky130A rule deck from the PDK.
# Inputs (environment variables set by the Makefile):
#   GDS  path to the GDS file
#   CELL name of the cell to check
#   MAGIC_TECH path to the sky130A .tech file (loaded directly; see the Makefile)
# Prints every violation with its rule name in parentheses. Magic also prints
# "Total DRC errors found: N" for the cell. The "MAGIC DRC:" line marks the run as finished.

tech load $env(MAGIC_TECH)
gds read $env(GDS)
load $env(CELL)
# The sky130 tech file defines the "drc" style in three variants. "full" runs every rule.
drc style drc(full)
drc on
drc check
drc catchup
# Print the error count first, so a run with no output is still visible in the log.
if {[catch {drc count} n]} {
  puts "MAGIC DRC COUNT: error $n"
} else {
  puts "MAGIC DRC COUNT: $n"
}
drc listall why
puts "MAGIC DRC: finished $env(CELL)"
quit -noprompt
