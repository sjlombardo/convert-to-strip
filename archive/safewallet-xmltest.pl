#!/usr/bin/perl

use strict;
use XML::LibXML;
use Data::Dumper;

## slurp it in to pwn v-tabs
# my $slurp_handle;
# open($slurp_handle, "<:encoding(UTF-16LE)", './samples/SafeWallet3-dq.xml');
# 
# $/ = undef;
# my $xml = <$slurp_handle>;
# # print $foo, "\n\n";
# ## Replace any vertical tab chars
# $xml =~ s"&#xB;"&#xA;"gi;
# # print $foo, "\n\n";
# close($slurp_handle);

## Feed $xml to xml loader
# my $parser = XML::LibXML->new;
# my $doc = $parser->load_xml(string => $xml, recover => 2) or die;

## read in data as raw UTF16, assumes a BOM present
open my $in, '<:raw:encoding(UTF-16)', './samples/SafeWallet3-dq.xml';
binmode $in;
$\ = "";
my $utf16 = <$in>;
close($in); 

my $utf8 = "";
open my $out, '>', \$utf8 or die "Can't open variable: $!";
binmode($out, ':raw:encoding(UTF-8)');
write $utf8, $utf16;
write <STDOUT>, $utf8;

# ## let's try a line-by-line slurp
# # read in data as raw UTF16, assumes a BOM present
# open my $in, '<:raw:encoding(UTF-16)', './samples/SafeWallet3-dq.xml';
# # binmode $in;
# my $utf8;
# open my $out, '>', \$utf8 or die "Can't open variable: $!";
# binmode($out, ':raw:encoding(UTF-8)');
# while <$in> { 
# 	print <$utf8>, $_;
# }
# close($in);
# close($out);
# print $utf8;

# my $doc = XML::LibXML->load_xml(IO => $fh) or die;

## this works:
# print $doc->toString . "\n\n";
# my $root = $doc->documentElement;
## this works:
# print $root->toString . "\n\n";
## apparently this does not... @nodes is empty array
# my @nodes = $root->getElementsByTagName('SafeWallet');
# print @nodes->toString . "\n\n";
## this doesn't work either, @nodes is empty array
# my @nodes = $doc->getElementsByTagName('SafeWallet');
# print @nodes->toString . "\n\n";
# my @nodes = $root->getElementsByTagName('T37');
# print @nodes->toString . "\n\n";

# my $isVersion3 = 0;
# my $root = $dom->documentElement();
# my @nodes = $root->getElementsByTagName('SafeWallet');
# if (scalar(@nodes) > 0) {
# 	my @t37nodes = $nodes[0]->getElementsByTagName('T37');
# 	if (scalar(@t37nodes) > 0) {
# 		$isVersion3 = 1;
# 	}
# }
