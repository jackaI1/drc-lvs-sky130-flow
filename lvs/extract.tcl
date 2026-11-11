# Magic extraction: turn the drawn layout back into a SPICE netlist for LVS.
# Inputs (environment variables set by the Makefile):
#   GDS  path to the GDS file
#   CELL name of the cell to extract
#   OUTDIR folder for the extracted netlist (written as <CELL>.spice)
#   MAGIC_TECH path to the sky130A .tech file (loaded directly; see the Makefile)

tech load $env(MAGIC_TECH)
gds read $env(GDS)
load $env(CELL)
extract do local
extract all
ext2spice lvs
ext2spice -o $env(OUTDIR)/$env(CELL).spice
quit -noprompt
