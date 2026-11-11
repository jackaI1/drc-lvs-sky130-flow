"""Design rules that the KLayout checks enforce.

Each rule keeps the sky130A rule name (poly.1a, met1.2, ...) so that a
violation can be matched with the same name in the Magic DRC report. Values
are in micrometres and come from the sky130A Magic tech file (values there are
in nm, so 150 there is 0.15 um here).
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Rule:
    rule_id: str  # sky130 rule name, e.g. "met1.2"
    kind: str  # "width" (narrowest part) or "space" (closest two shapes)
    layers: tuple  # layer names from layout/cells.py LAYERS
    min_um: float  # the rule fails when a measurement is below this
    text: str  # what the rule says, in words


RULES = [
    Rule("poly.1a", "width", ("poly",), 0.15, "poly width"),
    Rule("poly.2", "space", ("poly",), 0.21, "poly spacing"),
    Rule("diff/tap.1", "width", ("diff",), 0.15, "diffusion width"),
    Rule("diff/tap.3", "space", ("diff",), 0.27, "diffusion spacing"),
    Rule("li.1", "width", ("li",), 0.17, "local interconnect width"),
    Rule("mcon.1", "width", ("mcon",), 0.17, "mcon contact width"),
    Rule("mcon.2", "space", ("mcon",), 0.19, "mcon contact spacing"),
    Rule("met1.1", "width", ("met1",), 0.14, "metal1 width"),
    Rule("met1.2", "space", ("met1",), 0.14, "metal1 spacing"),
    Rule("nwell.1", "width", ("nwell",), 0.84, "n-well width"),
]
