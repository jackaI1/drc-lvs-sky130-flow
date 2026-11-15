# Magic self-test ("canary"): draw two metal1 wires that break known sky130 rules in a
# scratch cell, and check that Magic reports them. If it does not, the rule deck is
# not running, and the DRC results for the real cells cannot be trusted.
#   two wires 0.10 um wide, 0.10 um apart  -> met1.1 (width needs 0.14 um) and met1.2 (spacing needs 0.14 um)
# The Makefile checks the output for both rule names.
# Inputs: MAGIC_RC path to the PDK's sky130A.magicrc, PDK_ROOT (see the Makefile).

source $env(MAGIC_RC)
cellname create canary
load canary
select top cell
expand
view
drc style drc(full)
drc on
box 2um 0um 2.1um 1um
paint metal1
box 2.2um 0um 2.3um 1um
paint metal1
drc catchup
set total 0
foreach {rule pairs} [drc listall why] {
  foreach pair $pairs {
    puts "$rule  $pair"
    incr total
  }
}
puts "MAGIC CANARY: finished, $total violation(s)"
quit -noprompt
