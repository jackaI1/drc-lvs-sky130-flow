# Magic self-test ("canary"): draw metal1 shapes that break known sky130 rules in a
# scratch cell, and check that Magic reports them. If it does not, the rule deck is
# not running, and the DRC results for the real cells cannot be trusted.
#   step 1: one metal1 wire 0.10 um wide           -> met1.1 (width needs 0.14 um)
#   step 2: a second wire 0.10 um from the first   -> met1.2 (spacing needs 0.14 um)
# The Makefile checks the output for both rule names.
# Input: MAGIC_TECH path to the sky130A .tech file (see the Makefile).

tech load $env(MAGIC_TECH)
cellname create canary
load canary
drc style drc(full)
drc euclidean on
drc on
box 2um 0um 2.1um 1um
paint metal1
drc check
drc catchup
puts "CANARY step 1 errors: [drc count]"
box 2.2um 0um 2.3um 1um
paint metal1
drc check
drc catchup
puts "CANARY step 2 errors: [drc count]"
drc listall why
puts "MAGIC CANARY: finished"
quit -noprompt
