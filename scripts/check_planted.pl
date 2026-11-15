#!/usr/bin/env perl
# Check that every planted error is caught, and traced to the rule it should trip.
#
# Usage: perl scripts/check_planted.pl tests/planted_rules.txt build/reports
#
# For each planted DRC case, the rules found in its report are compared with the
# rules found in the clean inverter's report. A rule that appears only in the planted
# report was caused by the planted error, so the expected rule (from
# tests/planted_rules.txt) must be one of those new rules. Each planted LVS case must
# mismatch, and the clean inverter must match.
#
# KLayout is the reference DRC: the check fails if it misses an expected rule.
# Magic is reported in the table but does not fail the check. Its full sky130 deck
# finds different rules, and some of them it does not find at all (see the README).
#
# Exits 0 when every required check passes, and 1 otherwise.

use strict;
use warnings;

my ($expect_file, $dir) = @ARGV;
die "usage: check_planted.pl planted_rules.txt REPORT_DIR\n" unless defined $dir;

my %expect = read_expectations($expect_file);
my $fail = 0;

my $clean_k = rules_in("$dir/klayout_inverter.txt");
my $clean_m = rules_in("$dir/magic_inverter.txt");
my $clean_lvs = lvs_result("$dir/lvs_inverter.txt");
if (!defined $clean_k || !defined $clean_m) {
    print "MISSING clean inverter DRC reports in $dir\n";
    $fail = 1;
}
$clean_k ||= {};
$clean_m ||= {};

my $lvs_clean_ok = defined $clean_lvs && $clean_lvs eq 'MATCH';
print "Clean inverter LVS: " . ($lvs_clean_ok ? "MATCH (required)" : "NOT MATCH (required to match)") . "\n";
$fail = 1 unless $lvs_clean_ok;
print "\n";

printf "%-18s %-10s %-9s %-9s %s\n", 'CASE', 'EXPECTED', 'KLAYOUT', 'MAGIC', 'OTHER NEW MAGIC RULES';
printf "%s\n", '-' x 100;

my ($k_hits, $m_hits, $drc_cases, $lvs_hits, $lvs_cases) = (0, 0, 0, 0, 0);

for my $case (sort keys %expect) {
    my $rule = $expect{$case};
    if ($rule eq 'none') {
        # An LVS case: the drawn shapes are legal, so only the netlist comparison fails
        $lvs_cases++;
        my $lvs = lvs_result("$dir/lvs_$case.txt");
        my $caught = defined $lvs && $lvs eq 'MISMATCH';
        $lvs_hits++ if $caught;
        printf "%-18s %-10s %-9s %-9s %s\n", $case, 'LVS', '-', '-',
            $caught ? 'LVS mismatch (caught)' : 'LVS not run or still matches (MISSED)';
        $fail = 1 unless $caught;
        next;
    }

    $drc_cases++;
    my $k = rules_in("$dir/klayout_$case.txt");
    my $m = rules_in("$dir/magic_$case.txt");
    if (!defined $k || !defined $m) {
        print "MISSING DRC reports for $case in $dir\n";
        $fail = 1;
        next;
    }
    my $k_new = new_rules($k, $clean_k);
    my $m_new = new_rules($m, $clean_m);
    my $k_caught = exists $k_new->{$rule};
    my $m_caught = exists $m_new->{$rule};
    $k_hits++ if $k_caught;
    $m_hits++ if $m_caught;
    $fail = 1 unless $k_caught;

    my @other = sort grep { $_ ne $rule } keys %$m_new;
    my $other_text = @other ? join(', ', @other) : '-';
    printf "%-18s %-10s %-9s %-9s %s\n", $case, $rule,
        $k_caught ? 'caught' : 'MISSED', $m_caught ? 'caught' : 'missed', $other_text;
}

print "\n";
printf "KLayout caught %d of %d planted DRC errors (the required reference).\n", $k_hits, $drc_cases;
printf "Magic caught %d of %d planted DRC errors (reported, not required).\n", $m_hits, $drc_cases;
printf "LVS caught %d of %d planted netlist errors.\n", $lvs_hits, $lvs_cases;
print $fail ? "CHECK FAILED\n" : "CHECK PASSED\n";
exit($fail ? 1 : 0);

# Read "case rule" lines, skipping comments and blank lines.
sub read_expectations {
    my ($file) = @_;
    open my $fh, '<', $file or die "cannot read $file: $!\n";
    my %expect;
    while (my $line = <$fh>) {
        $line =~ s/#.*//;
        next unless $line =~ /\S/;
        my ($case, $rule) = split ' ', $line;
        die "bad line in $file: $line" unless defined $rule;
        $expect{$case} = $rule;
    }
    close $fh;
    return %expect;
}

# Rule names in a report, e.g. "(met1.2)" or "(diff/tap.1)". Undef if the file is missing.
sub rules_in {
    my ($file) = @_;
    open my $fh, '<', $file or return undef;
    my %rules;
    while (my $line = <$fh>) {
        while ($line =~ /\(([a-z][a-z0-9_]*(?:[\/.][a-z0-9]+)+)\)/gi) {
            $rules{$1} = 1;
        }
    }
    close $fh;
    return \%rules;
}

# Rules in the planted report that the clean report does not have.
sub new_rules {
    my ($found, $clean) = @_;
    return { map { $_ => 1 } grep { !exists $clean->{$_} } keys %$found };
}

# MATCH or MISMATCH from a Netgen report. Undef if the file is missing.
sub lvs_result {
    my ($file) = @_;
    open my $fh, '<', $file or return undef;
    my $text = do { local $/; <$fh> };
    close $fh;
    return 'MATCH' if $text =~ /match uniquely/i;
    return 'MISMATCH' if $text =~ /do not match|not match/i;
    return undef;
}
