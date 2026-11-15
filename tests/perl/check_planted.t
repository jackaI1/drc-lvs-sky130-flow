use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

my $script = 'scripts/check_planted.pl';
my $dir = tempdir(CLEANUP => 1);
my $expect = "$dir/planted_rules.txt";

write_file($expect, "# expectations\npoly_width poly.1a\nlvs_open_output none\n");
write_file("$dir/klayout_inverter.txt", "KLAYOUT DRC: 0 violation(s) in inverter.gds\n");
write_file("$dir/magic_inverter.txt", "nothing to report\n");
write_file("$dir/lvs_inverter.txt", "Circuits match uniquely.\n");
write_file("$dir/klayout_poly_width.txt",
    "inverter (poly.1a) poly width < 0.15 um: 0.10 um at (2.00,0.00)-(2.10,1.00)\n");
write_file("$dir/magic_poly_width.txt", "Poly width < 0.15um (poly.1a)  200 0 210 100\n");
write_file("$dir/klayout_lvs_open_output.txt", "KLAYOUT DRC: 0 violation(s) in lvs_open_output.gds\n");
write_file("$dir/magic_lvs_open_output.txt", "");
write_file("$dir/lvs_lvs_open_output.txt", "Netlists do not match.\n");

# Every planted error is caught and traced to its rule
my $out = `perl $script $expect $dir 2>&1`;
is($? >> 8, 0, 'passes when every planted error is caught');
like($out, qr/^poly_width\s+poly\.1a\s+caught\s+caught/m, 'poly_width is traced to poly.1a by both checkers');
like($out, qr/^lvs_open_output\s+LVS\s+.*mismatch \(caught\)/m, 'the LVS case counts as caught');
like($out, qr/KLayout caught 1 of 1 planted DRC errors/, 'KLayout count is printed');
like($out, qr/Clean inverter LVS: MATCH/, 'the clean inverter must match');
like($out, qr/CHECK PASSED/, 'overall result is PASSED');

# A planted error that KLayout misses fails the check, and the table says so
write_file("$dir/klayout_poly_width.txt", "KLAYOUT DRC: 0 violation(s) in poly_width.gds\n");
$out = `perl $script $expect $dir 2>&1`;
isnt($? >> 8, 0, 'fails when KLayout misses the expected rule');
like($out, qr/^poly_width\s+poly\.1a\s+MISSED/m, 'the missed case is marked MISSED');
like($out, qr/CHECK FAILED/, 'overall result is FAILED');

# The clean inverter must match the schematic
write_file("$dir/klayout_poly_width.txt",
    "inverter (poly.1a) poly width < 0.15 um: 0.10 um at (2.00,0.00)-(2.10,1.00)\n");
write_file("$dir/lvs_inverter.txt", "Netlists do not match.\n");
$out = `perl $script $expect $dir 2>&1`;
isnt($? >> 8, 0, 'fails when the clean inverter does not match');
like($out, qr/Clean inverter LVS: NOT MATCH/, 'the mismatch is reported for the clean inverter');

# Missing reports are reported and fail the check
unlink "$dir/klayout_poly_width.txt";
$out = `perl $script $expect $dir 2>&1`;
isnt($? >> 8, 0, 'fails when a report is missing');
like($out, qr/MISSING DRC reports for poly_width/, 'the missing report is named');

done_testing();

sub write_file {
    my ($path, $text) = @_;
    open my $fh, '>', $path or die "cannot write $path: $!\n";
    print $fh $text;
    close $fh;
}
