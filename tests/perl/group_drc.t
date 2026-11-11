use strict;
use warnings;
use Test::More;

my $script = 'scripts/group_drc.pl';
my $fx = 'tests/perl/fixtures';

# Two KLayout reports and one Magic report, grouped together
my $out = `perl $script $fx/klayout_met1_space.txt $fx/klayout_poly_width.txt $fx/magic_met1_space.txt 2>&1`;
is($? >> 8, 0, 'group_drc.pl exits 0');
like($out, qr/^met1\.2\s+2\s/m, 'met1.2 counted from KLayout and Magic files');
like($out, qr/^poly\.1a\s+1\s/m, 'poly.1a counted once');
like($out, qr/^diff\/tap\.1\s+1\s/m, 'diff/tap.1 keeps its slash in the rule name');
like($out, qr/TOTAL: 4 violation\(s\) across 3 rule\(s\)/, 'totals are right');
like($out, qr/klayout_met1_space\s+1/, 'per-file count is printed');

# Summary lines such as "KLAYOUT DRC: 0 violation(s)" must not count as rules
my $clean = `perl $script $fx/clean.txt 2>&1`;
like($clean, qr/TOTAL: 0 violation\(s\) across 0 rule\(s\)/, 'clean report has no rules');

# No arguments should fail with a usage message
my $none = `perl $script 2>&1`;
isnt($? >> 8, 0, 'no arguments is an error');
like($none, qr/usage/, 'prints usage');

done_testing();
