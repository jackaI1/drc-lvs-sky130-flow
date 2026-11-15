# Magic self-test ("canary"): draw two metal1 wires 0.10 um apart in a scratch cell.
# The sky130 metal1 spacing rule (met1.2) needs 0.14 um, so Magic must flag them.
# If it does not, the rule deck is not running, and the DRC results for the real
# cells cannot be trusted. The Makefile checks the output for "(met1.2)".
# Input: MAGIC_TECH path to the sky130A .tech file (see the Makefile).

tech load $env(MAGIC_TECH)
cellname create canary
load canary
drc style drc(full)
drc on
box 2um 0um 2.1um 1um
paint metal1
box 2.2um 0um 2.3um 1um
paint metal1
drc check
drc catchup
drc listall why
puts "MAGIC CANARY: finished"
quit -noprompt
