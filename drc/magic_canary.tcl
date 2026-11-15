# Magic self-test ("canary"): draw two metal1 wires 0.10 um wide with a 0.10 um gap in a
# scratch cell. The sky130 spacing rule (met1.2) needs 0.14 um, so Magic must report it.
# If it does not, the rule deck is not running, and the DRC results for the real cells
# cannot be trusted. The Makefile checks the output for "(met1.2)".
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
