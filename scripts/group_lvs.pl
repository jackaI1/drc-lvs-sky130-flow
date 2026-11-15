#!/usr/bin/env perl
# Summarise Netgen LVS results, one line per layout case.
#
# Reads the report files written by `make lvs` (lvs_*.txt). A report that
# contains "match uniquely" is a MATCH. Anything else is a MISMATCH, and the
# lines that mention nets, devices or pins are counted by kind so you can
# see what kind of problem Netgen found.
#
# Usage: perl scripts/group_lvs.pl build/reports/lvs_*.txt

use strict;
use warnings;

my @files = @ARGV;
die "usage: group_lvs.pl REPORT [REPORT ...]\n" unless @files;

printf "%-20s %-9s %-7s %-22s %s\n", 'CASE', 'RESULT', 'ISSUES', 'BY KIND', 'FIRST ISSUE';
printf "%s\n", '-' x 100;

for my $file (@files) {
    my ($case) = $file =~ m{lvs_([^/]+?)\.txt$};
    $case //= $file;

    open my $fh, '<', $file or do {
        printf "%-20s %-9s\n", $case, 'MISSING';
        next;
    };
    my @lines = <$fh>;
    close $fh;
    chomp @lines;

    my $matched = grep { /match uniquely/i } @lines;
    if ($matched) {
        printf "%-20s %-9s %-7s %-22s %s\n", $case, 'MATCH', 0, '-', '-';
        next;
    }

    my %kind = (net => 0, device => 0, pin => 0, other => 0);
    my $first = '';
    for my $line (@lines) {
        next unless $line =~ /\b(differ|mismatch|do not match|not equivalent|unmatched|different)\b/i
            || $line =~ /\b(net|device|pin)s?\b/i;
        if ($line =~ /\bnets?\b/i)        { $kind{net}++ }
        elsif ($line =~ /\bdevices?\b/i)  { $kind{device}++ }
        elsif ($line =~ /\bpins?\b/i)     { $kind{pin}++ }
        else                              { $kind{other}++ }
        $first ||= $line;
    }
    my $issues = $kind{net} + $kind{device} + $kind{pin} + $kind{other};
    my $by_kind = join ' ', map { "$_:$kind{$_}" } grep { $kind{$_} } sort keys %kind;
    $first = substr($first, 0, 45) . '...' if length($first) > 48;
    $first = 'no detail in report' if $first eq '';
    printf "%-20s %-9s %-7d %-22s %s\n", $case, 'MISMATCH', $issues, $by_kind || '-', $first;
}
