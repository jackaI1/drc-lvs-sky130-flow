"""Draw the test standard cells as GDS files.

Every shape is in micrometres (um). The cells are small hand-drawn versions of
a sky130 inverter, using the sky130A GDS layer numbers from the SkyWater PDK
Magic tech file. They are meant for checking the flow, not for a tape-out.

Run `python3 layout/cells.py build/` to write:
  build/inverter.gds             clean cell (should have 0 DRC errors)
  build/planted/<case>.gds       the same cell with one known error added
"""

import os
import sys

import klayout.db as db

# name -> (GDS layer, datatype), from the sky130A Magic tech file
LAYERS = {
    "nwell": (64, 20),
    "diff": (65, 20),
    "tap": (65, 44),
    "poly": (66, 20),
    "licon": (66, 44),  # contact between poly/diff and li
    "li": (67, 20),
    "mcon": (67, 44),  # contact between li and met1
    "met1": (68, 20),
    "nsdm": (93, 44),
    "psdm": (94, 20),
    "met1_label": (68, 5),
    "met1_pin": (68, 16),
}

# Every case that can be planted. Each DRC case adds one known error that only
# trips the rule in its comment (the shape sits in empty space at x >= 2.0 um,
# except poly_space, which sits 0.15 um from the gate). The LVS cases change
# the connections instead, so Netgen sees a different circuit.
PLANTED_CASES = [
    "poly_width",      # gate-like poly 0.10 um wide        -> poly.1a
    "poly_space",      # poly strip 0.15 um from the gate   -> poly.2
    "met1_width",      # met1 wire 0.10 um wide             -> met1.1
    "met1_space",      # two met1 wires 0.10 um apart       -> met1.2
    "li_width",        # local interconnect 0.12 um wide    -> li.1
    "mcon_width",      # 0.15 um mcon contact               -> mcon.1
    "mcon_space",      # two mcons 0.10 um apart            -> mcon.2
    "nwell_width",     # nwell 0.60 um wide                 -> nwell.1
    "diff_width",      # diffusion 0.10 um wide             -> diff/tap.1
    "diff_space",      # two diffusions 0.10 um apart       -> diff/tap.3
    "lvs_open_output", # output li strip removed: Y is open -> LVS mismatch
    "lvs_short_rails", # met1 bridge joins GND and VDD      -> LVS mismatch
]


def _box(shapes, layer_name, layer_index, x1, y1, x2, y2, dbu):
    shapes.insert(db.Box(round(x1 / dbu), round(y1 / dbu), round(x2 / dbu), round(y2 / dbu)))


def _draw_inverter(layout, top, plant):
    """Draw an inverter: NMOS at the bottom, PMOS in an n-well at the top.

    Pins: A (input, gate), Y (output, drains), VDD (top rail), GND (bottom rail).
    """
    dbu = layout.dbu
    idx = {name: layout.layer(*LAYERS[name]) for name in LAYERS}

    def box(name, x1, y1, x2, y2):
        _box(top.shapes(idx[name]), name, idx[name], x1, y1, x2, y2, dbu)

    def text(name, s, x, y):
        top.shapes(idx[name]).insert(db.Text(s, db.Trans(round(x / dbu), round(y / dbu))))

    # NMOS: diffusion 1.0 x 0.6 um, gate poly 0.15 um long at x 0.40-0.55
    box("diff", 0.00, 0.00, 1.00, 0.60)
    box("nsdm", -0.13, -0.13, 1.13, 0.73)
    # PMOS: diffusion in an n-well
    box("diff", 0.00, 1.60, 1.00, 2.20)
    box("psdm", -0.13, 1.47, 1.13, 2.33)
    box("nwell", -0.40, 1.20, 2.10, 2.60)
    # N+ tap in the n-well, tied to VDD
    box("tap", 1.45, 1.80, 1.75, 2.20)
    box("nsdm", 1.32, 1.67, 1.88, 2.33)

    # One gate poly strip over both devices, with a pad at the bottom for input A
    box("poly", 0.40, -0.90, 0.55, 2.40)
    box("poly", 0.40, -0.90, 0.70, -0.50)

    # Contacts (licon) and local interconnect (li) for each terminal
    box("licon", 0.45, -0.785, 0.62, -0.615)   # gate A
    box("li", 0.37, -0.865, 0.70, -0.535)
    box("licon", 0.055, 0.215, 0.225, 0.385)   # NMOS source
    box("li", -0.025, 0.135, 0.305, 0.465)
    box("licon", 0.055, 1.815, 0.225, 1.985)   # PMOS source
    box("li", -0.025, 1.735, 0.305, 2.065)
    box("licon", 0.69, 0.215, 0.86, 0.385)     # NMOS drain
    box("licon", 0.69, 1.815, 0.86, 1.985)     # PMOS drain
    box("licon", 1.515, 1.915, 1.685, 2.085)   # N+ tap
    box("li", 1.435, 1.835, 1.765, 2.165)
    if plant != "lvs_open_output":
        box("li", 0.61, 0.135, 0.94, 2.065)    # output Y joins both drains
    box("mcon", 0.69, 0.915, 0.86, 1.085)      # Y contact to met1, mid-height

    # Metal1 pads on the contacts
    box("mcon", 0.45, -0.785, 0.62, -0.615)
    box("met1", 0.42, -0.815, 0.65, -0.585)    # pin A
    box("mcon", 0.055, 0.215, 0.225, 0.385)
    box("mcon", 0.055, 1.815, 0.225, 1.985)
    box("mcon", 1.515, 1.915, 1.685, 2.085)
    box("met1", 0.66, 0.885, 0.89, 1.115)      # pin Y

    # GND strip, from the NMOS source down to the bottom edge
    box("met1", 0.025, -1.60, 0.255, 0.415)
    # VDD strip from the PMOS source up, with a bus across the top to the tap
    box("met1", 0.025, 1.785, 0.255, 3.00)
    box("met1", 0.025, 2.45, 1.73, 2.65)
    box("met1", 1.50, 1.87, 1.73, 2.65)

    # P+ substrate tap outside the n-well, tied to GND, so the NMOS body is GND
    box("tap", 1.45, -0.60, 1.75, -0.20)
    box("psdm", 1.325, -0.725, 1.875, -0.075)
    box("licon", 1.515, -0.485, 1.685, -0.315)
    box("li", 1.435, -0.565, 1.765, -0.235)
    box("mcon", 1.515, -0.485, 1.685, -0.315)
    box("met1", 1.485, -0.515, 1.715, -0.16)
    box("met1", 0.025, -0.30, 1.715, -0.16)  # bar from the tap to the GND strip

    if plant == "lvs_short_rails":
        box("met1", 0.025, 0.30, 0.255, 1.90)  # bridges GND and VDD

    text("met1_pin", "A", 0.475, -0.70)
    text("met1_pin", "Y", 0.775, 1.00)
    text("met1_pin", "GND", 0.14, -1.30)
    text("met1_pin", "VDD", 0.14, 2.90)
    text("met1_label", "A", 0.475, -0.70)
    text("met1_label", "Y", 0.775, 1.00)
    text("met1_label", "GND", 0.14, -1.30)
    text("met1_label", "VDD", 0.14, 2.90)


def _draw_planted(layout, top, case):
    """Add one isolated error, far to the right of the cell (x >= 2.0 um)."""
    dbu = layout.dbu
    idx = {name: layout.layer(*LAYERS[name]) for name in LAYERS}

    def box(name, x1, y1, x2, y2):
        _box(top.shapes(idx[name]), name, idx[name], x1, y1, x2, y2, dbu)

    if case == "poly_width":
        box("poly", 2.00, 0.00, 2.10, 1.00)
    elif case == "poly_space":
        # 0.15 um from the gate's right edge (x = 0.55) at x = 0.70
        box("poly", 0.70, 0.70, 0.85, 0.90)
    elif case == "met1_width":
        box("met1", 2.00, 0.00, 2.10, 1.00)
    elif case == "met1_space":
        box("met1", 2.40, 0.00, 2.60, 1.00)
        box("met1", 2.70, 0.00, 2.90, 1.00)
    elif case == "li_width":
        box("li", 2.00, 0.00, 2.12, 1.00)
    elif case == "mcon_width":
        box("mcon", 2.00, 0.00, 2.15, 0.15)
    elif case == "mcon_space":
        box("mcon", 2.00, 0.00, 2.17, 0.17)
        box("mcon", 2.27, 0.00, 2.44, 0.17)
    elif case == "diff_space":
        box("diff", 2.00, 0.00, 2.50, 1.00)
        box("diff", 2.60, 0.00, 3.10, 1.00)
    elif case == "nwell_width":
        box("nwell", 2.00, 0.00, 2.60, 1.00)
    elif case == "diff_width":
        box("diff", 2.00, 0.00, 2.10, 1.00)


def build(case=None):
    """Return a layout with the clean inverter, or the inverter plus one planted case."""
    layout = db.Layout()
    layout.dbu = 0.001
    top = layout.create_cell("inverter")
    plant = case if case in ("lvs_open_output", "lvs_short_rails") else None
    _draw_inverter(layout, top, plant)
    if case and plant is None:
        _draw_planted(layout, top, case)
    return layout


def main(argv):
    out = argv[1] if len(argv) > 1 else "build"
    os.makedirs(os.path.join(out, "planted"), exist_ok=True)
    build().write(os.path.join(out, "inverter.gds"))
    for case in PLANTED_CASES:
        build(case).write(os.path.join(out, "planted", case + ".gds"))
    print(f"wrote {out}/inverter.gds and {len(PLANTED_CASES)} planted cases")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
