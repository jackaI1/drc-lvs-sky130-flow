# DRC and LVS flow for the sky130 test cells.
#
#   make layouts     draw the GDS files (clean inverter + planted errors)
#   make drc         KLayout and Magic design rule checks on every GDS file
#   make lvs         Magic extraction + Netgen layout-vs-schematic compare
#   make report      group every result by rule (Perl) and print the tables
#   make test        Python and Perl unit tests (no PDK needed)
#   make all         everything above
#
# Magic, Netgen and the sky130A PDK are only needed for magic-drc and lvs.
# CI installs them (see .github/workflows/drc-lvs.yml).

PYTHON ?= python3
PERL ?= perl
BUILD ?= build
REPORTS := $(BUILD)/reports
PDK_ROOT ?= $(HOME)/.volare
PDK ?= sky130A
PDK_DIR := $(PDK_ROOT)/$(PDK)
MAGIC_RC := $(PDK_DIR)/libs.tech/magic/$(PDK).magicrc
NETGEN_SETUP := $(PDK_DIR)/libs.tech/netgen/$(PDK)_setup.tcl

CASES := $(shell awk '$$1 ~ /^[a-z0-9_]+$$/ {print $$1}' tests/planted_rules.txt | sort -u)
GDS := $(BUILD)/inverter.gds $(addprefix $(BUILD)/planted/,$(addsuffix .gds,$(CASES)))
STAMP := $(BUILD)/.layouts

.PHONY: all layouts drc klayout-drc magic-drc lvs report test clean

all: test drc lvs report

layouts: $(STAMP)

$(STAMP): layout/cells.py
	$(PYTHON) layout/cells.py $(BUILD)
	@touch $(STAMP)

klayout-drc: layouts
	@mkdir -p $(REPORTS)
	@for g in $(GDS); do \
	  n=$$(basename $$g .gds); \
	  $(PYTHON) drc/klayout_drc.py $$g > $(REPORTS)/klayout_$$n.txt; \
	  tail -n 1 $(REPORTS)/klayout_$$n.txt; \
	done

magic-drc: layouts
	@mkdir -p $(REPORTS)
	@for g in $(GDS); do \
	  n=$$(basename $$g .gds); \
	  GDS=$$PWD/$$g CELL=inverter magic -dnull -noconsole -rcfile $(MAGIC_RC) \
	    < drc/magic_drc.tcl > $(REPORTS)/magic_$$n.txt 2>&1; \
	  grep "MAGIC DRC:" $(REPORTS)/magic_$$n.txt || echo "MAGIC DRC: no summary for $$n"; \
	done

drc: klayout-drc magic-drc

LVS_GDS := $(BUILD)/inverter.gds $(BUILD)/planted/lvs_open_output.gds $(BUILD)/planted/lvs_short_rails.gds

lvs: layouts
	@mkdir -p $(REPORTS)
	@for g in $(LVS_GDS); do \
	  n=$$(basename $$g .gds); \
	  mkdir -p $(BUILD)/extracted/$$n; \
	  GDS=$$PWD/$$g CELL=inverter OUTDIR=$$PWD/$(BUILD)/extracted/$$n \
	    magic -dnull -noconsole -rcfile $(MAGIC_RC) < lvs/extract.tcl > $(BUILD)/extracted/$$n/extract.log 2>&1; \
	  netgen -batch lvs \
	    "$(BUILD)/extracted/$$n/inverter.spice inverter" \
	    "lvs/inverter.spice inverter" \
	    $(NETGEN_SETUP) $(REPORTS)/lvs_$$n.txt > /dev/null 2>&1; \
	  echo "LVS $$n: $$(grep -m1 -E 'match uniquely|do not match|not match' $(REPORTS)/lvs_$$n.txt || echo 'no result')"; \
	done

report:
	@echo "== DRC by rule (KLayout + Magic) =="
	@$(PERL) scripts/group_drc.pl $(REPORTS)/klayout_*.txt $(REPORTS)/magic_*.txt
	@echo
	@echo "== LVS by case =="
	@$(PERL) scripts/group_lvs.pl $(REPORTS)/lvs_*.txt

test:
	$(PYTHON) -m unittest discover -s tests -p 'test_*.py' -v
	prove -r tests/perl

clean:
	rm -rf $(BUILD)
