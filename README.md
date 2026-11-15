# drc-lvs-sky130-flow

I built a free checker for chip layouts, using the open SkyWater sky130 process, because I wanted to learn how a drawn chip is checked before it goes to the factory. The professional tools that do this cost a lot of money, so I used the open ones: KLayout and Magic for the rule checks, and Netgen for the comparison with the circuit diagram.

## What the checks do

A chip layout is a set of shapes on different layers, drawn in a program like a map. Two checks catch most mistakes before manufacturing:

- **DRC (design rule check)** looks for shapes that are too thin, or too close to each other, for the factory to make reliably. Each rule has a name from the process, such as `met1.2` for the spacing between metal wires.
- **LVS (layout versus schematic)** pulls the transistors and wires back out of the drawing and checks that they connect the same way as the circuit diagram. If a wire is missing or two nets are shorted, LVS says so.

To check that the checks work, I drew a small inverter (the simplest logic gate) and then planted known errors into copies of it. Each planted error breaks one specific rule, so the checker should catch it and name that rule. A script then groups every result by rule.

## How to use it

You need Python 3 with the `klayout` package, and Perl. The Magic and Netgen steps also need Magic 8.3.411, Netgen and the sky130A PDK. The GitHub Actions workflow installs all of these on every push, so you can read the results there.

```sh
pip install klayout
make layouts        # draw the GDS files: the clean inverter and the planted errors
make klayout-drc    # KLayout design rule checks
make magic-drc      # Magic design rule checks with the full sky130 rule deck
make lvs            # Magic extracts the netlist, Netgen compares it with the schematic
make report         # group every result by rule, with Perl
make check          # fail unless every planted error is caught by its rule
make test           # Python and Perl unit tests (no PDK needed)
```

The planted errors and the rule each one should trip are listed in `tests/planted_rules.txt`.

## Results

These numbers come from the latest CI run on this repository.

| Check | Result |
| --- | --- |
| KLayout DRC: planted errors caught by their rule | 10 of 10 |
| Magic DRC: planted errors caught by their rule | 4 of 10 (3 of 4 spacing rules, 1 of 6 width rules) |
| LVS: clean inverter matches its schematic | yes |
| LVS: planted netlist errors caught | 2 of 2 |
| Unit tests | 5 Python tests and 27 Perl checks, all passing |

The Magic result is the honest weak spot. On my test shapes, Magic did not flag several width errors, such as a 0.10 um wire under the 0.14 um metal rule, and I did not find out why. KLayout catches those. The `make check` step treats KLayout as the required reference and reports Magic's result without failing on it.

Magic's full sky130 rule deck also flags 58 rules on the clean inverter. My drawing is a small test shape, not a real cell, so it does not pass every contact and enclosure rule. The report shows these as baseline, and each planted case is compared against the clean inverter so only the new rules count.

## What is in the repository

- `layout/cells.py` draws the inverter and each planted error as a GDS file, using the sky130A layer numbers.
- `drc/rules.py` lists the rules that the KLayout check enforces, with the same names as the sky130 rules.
- `drc/klayout_drc.py` runs those rules on a GDS file with KLayout's Python API and prints one line per error.
- `drc/magic_drc.tcl` runs Magic's full sky130 DRC deck on a GDS file. `drc/magic_canary.tcl` draws a known violation and checks that Magic reports it, so a broken setup fails loudly.
- `lvs/extract.tcl` makes Magic extract the netlist, `lvs/inverter.spice` is the schematic, and `lvs/run_lvs.tcl` runs Netgen.
- `scripts/group_drc.pl` and `scripts/group_lvs.pl` group the reports by rule and by case.
- `scripts/check_planted.pl` checks that each planted error is caught by the rule it should trip.
- `tests/` holds the Python tests (`test_drc.py`), the Perl tests (`tests/perl/`) and the planted-error list.

## How it is built

The KLayout check reads each GDS file, merges the shapes on each layer, and then runs a width check or a spacing check for each rule. Magic uses the PDK's own startup file, so it gets the same tech, grid and DRC options the PDK authors use. For LVS, Magic writes a SPICE netlist from the layout and Netgen compares it with the hand-written schematic. Both schematic and extracted netlist write each transistor as an instance of the PDK device, so Netgen compares like with like.

The CI workflow runs in two jobs. The unit test job needs only Python and Perl. The full flow job builds Magic 8.3.411 from source, installs the sky130A PDK with `volare`, runs every check, uploads the reports as an artifact, and fails if a planted error is not caught.

## Limitations

- The KLayout deck has 10 rules that I wrote for this flow. It is not the full sky130 deck; Magic's deck is.
- The inverter is a hand-drawn test shape, not a real standard cell, and LVS is only tested on that one cell.
- Magic's width rules did not fire on my test shapes, so I would not trust Magic alone for width checks without more work.
