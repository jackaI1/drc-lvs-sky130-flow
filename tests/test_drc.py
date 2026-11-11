"""Tests for the KLayout DRC checks and the test cells.

No PDK or Magic is needed: these run the KLayout checks on GDS files that the
tests draw themselves. They check that:
  * the clean inverter has no violations,
  * each planted error trips exactly the rule that tests/planted_rules.txt names,
  * every rule in drc/rules.py has at least one planted error.
"""

import os
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from drc.klayout_drc import check  # noqa: E402
from drc.rules import RULES  # noqa: E402
from layout.cells import PLANTED_CASES, build  # noqa: E402

EXPECTED_FILE = os.path.join(ROOT, "tests", "planted_rules.txt")


def load_expectations():
    """Return {case: rule_id or None} from tests/planted_rules.txt."""
    expected = {}
    with open(EXPECTED_FILE) as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            case, rule = line.split()
            expected[case] = None if rule == "none" else rule
    return expected


class DrcTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        cls.workdir = cls._tmp.name

    @classmethod
    def tearDownClass(cls):
        cls._tmp.cleanup()

    def gds_for(self, case):
        """Draw the layout for one case and write it to a temporary GDS file."""
        path = os.path.join(self.workdir, f"{case or 'clean'}.gds")
        build(case).write(path)
        return path

    def test_clean_inverter_has_no_violations(self):
        self.assertEqual(check(self.gds_for(None)), [])

    def test_every_planted_case_trips_its_rule(self):
        expected = load_expectations()
        for case, rule in expected.items():
            with self.subTest(case=case):
                violations = check(self.gds_for(case))
                rules_hit = {v.rule_id for v in violations}
                if rule is None:
                    # LVS-only cases: the drawn shapes are legal, only connectivity changes
                    self.assertEqual(violations, [], f"{case} should pass DRC")
                else:
                    self.assertEqual(rules_hit, {rule}, f"{case} should trip only {rule}")

    def test_every_rule_has_a_planted_case(self):
        covered = {rule for rule in load_expectations().values() if rule}
        for rule in RULES:
            with self.subTest(rule=rule.rule_id):
                self.assertIn(rule.rule_id, covered)

    def test_planted_cases_match_the_case_list_in_cells(self):
        self.assertEqual(sorted(load_expectations()), sorted(PLANTED_CASES))

    def test_violation_line_names_the_rule(self):
        violations = check(self.gds_for("met1_space"))
        self.assertEqual(len(violations), 1)
        line = violations[0].line()
        self.assertIn("(met1.2)", line)
        self.assertIn("0.10 um", line)


if __name__ == "__main__":
    unittest.main()
