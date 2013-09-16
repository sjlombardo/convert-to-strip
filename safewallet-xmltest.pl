#!/usr/bin/perl

# $foo = 'asdffoo&#xb;bar';
my $fh;
open($fh, "<:encoding(UTF-16LE)", './SafeWallet.xml');

$/ = undef;
$foo = <$fh>;

print $foo, "\n\n";

$foo =~ s"&#xB;"&#xA;"gi;

print $foo, "\n\n";

close($fh);
