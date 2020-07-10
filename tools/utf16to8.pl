#!/usr/bin/perl

# Usage:
#   utf16to8.pl infile > outfile
# this is an interesting trick/script from http://www.perlmonks.org/?node_id=719216
#
# ":raw is needed to disable the crlf layer if present. It would corrupt the data on the UTF-16 
# side, and the UTF-8 sides needs it to mirror the UTF-16 side."


use strict;
use warnings;

binmode(STDOUT, ':raw:encoding(UTF-8)');

for my $qfn (@ARGV) {
	# Assumes the presence of a BOM.
	open(my $fh, "<:raw:encoding(UTF-16)", $qfn)
		or die("Can't open \"$qfn\": $!\n");

## From the original, just dumps to STD OUT, looks like:
## "GLOB(0x7ff69a050a70)<SafeWallet WalletName="donald_quander@hotmail.com">" on each line
# 	print while <$fh>;

	my $string = "";
	open(my $out, '>', \$string) or die "Could not open $! for writing";
	binmode($out, ':raw:encoding(UTF-8)');
	while (<$fh>) {
		print $out $_;
	}
	print \$string;
}
