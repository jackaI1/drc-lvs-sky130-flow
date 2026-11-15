"""Check a GDS file against the sky130 rules in drc/rules.py, using KLayout's Python API.

Usage:
    python3 drc/klayout_drc.py build/inverter.gds [--cell inverter]

Each violation is printed on one line that ends with the rule name in
parentheses, for example:
    inverter (met1.2) metal1 spacing < 0.14 um: 0.10 um at (2.60,0.00)-(2.70,1.00)
The Perl script scripts/group_drc.pl counts these lines by rule name.

It exits 0 when no rule is broken, and 1 when there are violations.
"""

import argparse
import os
import sys
from dataclasses import dataclass

import klayout.db as db

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from drc.rules import RULES  # noqa: E402
from layout.cells import LAYERS  # noqa: E402


@dataclass(frozen=True)
class Violation:
    rule_id: str
    cell: str
    text: str
    x1: float
    y1: float
    x2: float
    y2: float

    def line(self):
        return (
            f"{self.cell} ({self.rule_id}) {self.text} "
            f"at ({self.x1:.2f},{self.y1:.2f})-({self.x2:.2f},{self.y2:.2f})"
        )


def _layer_region(layout, cell, layer_name):
    index = layout.layer(*LAYERS[layer_name])
    return db.Region(cell.begin_shapes_rec(index)).merged()


def check(gds_path, cell_name=None):
    """Return the list of Violation objects for every rule in drc/rules.py."""
    layout = db.Layout()
    layout.read(gds_path)
    cell = layout.cell(cell_name) if cell_name else layout.top_cell()
    dbu = layout.dbu
    found = []
    seen = set()

    for rule in RULES:
        # A rule may cover several layers, so check each one separately.
        for layer_name in rule.layers:
            region = _layer_region(layout, cell, layer_name)
            limit = round(rule.min_um / dbu)
            if rule.kind == "width":
                pairs = region.width_check(limit)
            else:
                pairs = region.space_check(limit)
            for pair in pairs.each():
                box = pair.bbox()
                key = (rule.rule_id, box.left, box.bottom, box.right, box.top)
                if key in seen:  # a square shape can fail in both x and y
                    continue
                seen.add(key)
                measured = _measured(pair, dbu)
                found.append(Violation(
                    rule_id=rule.rule_id,
                    cell=cell.name,
                    text=f"{rule.text} < {rule.min_um:.2f} um: {measured:.2f} um",
                    x1=box.left * dbu, y1=box.bottom * dbu,
                    x2=box.right * dbu, y2=box.top * dbu,
                ))
    return found


def _measured(edge_pair, dbu):
    """The width or gap that failed, in um.

    For a pair of opposite edges the failing dimension is the short side of
    the pair's bounding box: the narrow width, or the gap between two shapes.
    """
    box = edge_pair.bbox()
    return min(box.width(), box.height()) * dbu


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("gds")
    parser.add_argument("--cell", default=None, help="cell to check (default: top cell)")
    args = parser.parse_args(argv[1:])

    violations = check(args.gds, args.cell)
    for v in violations:
        print(v.line())
    print(f"KLAYOUT DRC: {len(violations)} violation(s) in {os.path.basename(args.gds)}")
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
