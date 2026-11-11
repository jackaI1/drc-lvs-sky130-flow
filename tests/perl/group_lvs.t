use strict;
use warnings;
use Test::More;

my $script = 'scripts/group_lvs.pl';
my $fx = 'tests/perl/fixtures';

my $out = `perl $script $fx/lvs_match.txt $fx/lvs_open_output.txt 2>&1`;
is($? >> 8, 0, 'group_lvs.pl exits 0');
like($out, qr/^match\s+MATCH/m, 'a report with "match uniquely" is MATCH');
like($out, qr/^open_output\s+MISMATCH/m, 'a report without it is MISMATCH');
like($out, qr/net:2/, 'net differences are counted');
like($out, qr/device:1/, 'device differences are counted');

done_testing();
