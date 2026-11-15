# Magic DRC on one GDS cell, using the full sky130A rule deck from the PDK.
# Inputs (environment variables set by the Makefile):
#   GDS      path to the GDS file
#   CELL     name of the cell to check
#   MAGIC_RC path to the PDK's sky130A.magicrc (sets the tech, grid and DRC options)
#   PDK_ROOT folder that holds the sky130A PDK
# Magic returns the errors as a list, so this script prints one line per error with
# its rule name in parentheses, for example "Metal1 spacing < 140 (met1.2) {x y x y}".
# The Perl script scripts/group_drc.pl counts these lines by rule name.
# The last line, "MAGIC DRC: finished ...", marks the run as finished.

source $env(MAGIC_RC)
gds read $env(GDS)
load $env(CELL)
select top cell
expand
view
# The sky130 tech file defines the "drc" style in three variants. "full" runs every rule.
drc style drc(full)
drc on
drc catchup
set total 0
foreach {rule pairs} [drc listall why] {
  foreach pair $pairs {
    puts "$rule  $pair"
    incr total
  }
}
puts "MAGIC DRC: finished $env(CELL), $total violation(s)"
quit -noprompt
