#!/usr/bin/env perl
# Group DRC violations by rule name.
#
# Reads the report files written by drc/klayout_drc.py (klayout_*.txt) and by
# `make magic-drc` (magic_*.txt). Every violation line contains its sky130 rule
# name in parentheses, such as "(met1.2)" or "(diff/tap.1)". This script counts
# those lines per rule and lists which report files each rule was found in.
#
# Usage: perl scripts/group_drc.pl build/reports/klayout_*.txt build/reports/magic_*.txt

use strict;
use warnings;

my @files = @ARGV;
die "usage: group_drc.pl REPORT [REPORT ...]\n" unless @files;

my %count;      # rule => number of violations
my %found_in;   # rule => { report name => 1 }
my %example;    # rule => first violation line seen
my %per_file;   # report name => number of violations in that file

for my $file (@files) {
    my ($name) = $file =~ m{([^/]+?)(?:\.txt)?$};
    $per_file{$name} = 0;
    open my $fh, '<', $file or do {
        warn "cannot read $file: $!\n";
        next;
    };
    while (my $line = <$fh>) {
        chomp $line;
        # A rule name always has a dot or a slash, e.g. met1.2 or diff/tap.1.
        # This skips summary lines such as "KLAYOUT DRC: 0 violation(s)".
        next unless $line =~ /\(([a-z][a-z0-9_]*(?:[\/.][a-z0-9]+)+)\)/i;
        my $rule = $1;
        $count{$rule}++;
        $found_in{$rule}{$name} = 1;
        $example{$rule} //= $line;
        $per_file{$name}++;
    }
    close $fh;
}

print "Violations per report file:\n";
for my $name (sort keys %per_file) {
    printf "  %-28s %3d\n", $name, $per_file{$name};
}

print "\n";
printf "%-12s %6s  %-44s  %s\n", 'RULE', 'COUNT', 'FOUND IN', 'EXAMPLE';
printf "%s\n", '-' x 110;

my $total = 0;
for my $rule (sort keys %count) {
    my $sources = join ', ', sort keys %{ $found_in{$rule} };
    my $ex = $example{$rule};
    $ex = substr($ex, 0, 60) . '...' if length($ex) > 63;
    printf "%-12s %6d  %-44s  %s\n", $rule, $count{$rule}, substr($sources, 0, 44), $ex;
    $total += $count{$rule};
}

my $rules = scalar keys %count;
print "\nTOTAL: $total violation(s) across $rules rule(s)\n";
