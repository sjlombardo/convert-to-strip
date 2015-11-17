#!/usr/bin/perl -w

use strict;
use English;
use FileHandle;
use Fcntl;
use File::Basename;
use POSIX qw(tmpnam);
use Term::ReadKey;
use Tkx;
use Text::CSV;
use Text::CSV_XS;
use Text::CSV_PP;
use JSON;
use Data::Dumper;
use Encode;
# use XML::Parser;
# use XML::SimpleObject;
use XML::LibXML;

use utf8;
use warnings;
use warnings    qw< FATAL  utf8     >;

use vars qw($opt_source $opt_target $file);

my $IS_AQUA = Tkx::tk_windowingsystem() eq "aqua";

my $mw = Tkx::widget->new(".");
$mw->g_wm_title("Convert to Codebook");

my $frame = $mw->new_frame();
$frame->g_pack(-anchor=>'center', -padx => 20, -pady => 20);

my $source_button = $frame->new_ttk__button(-text => 'Source File',  -command => \&getSource);
$source_button->g_grid(-row => 1, -column => 0, -sticky => 'nw', -padx => 10, -pady => 5);

my $directory_entry = $frame->new_ttk__entry(-width => 60, -textvariable => \$opt_source);
$directory_entry->g_grid(-row => 1, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5, -columnspan => 2);

my $file_button = $frame->new_ttk__button(-text => 'Save As',  -command => \&getTarget);
$file_button->g_grid(-row => 2, -column => 0, -sticky => 'nw', -padx => 10, -pady => 5);

my $file_entry = $frame->new_ttk__entry(-width => 60, -textvariable => \$opt_target);
$file_entry->g_grid(-row => 2, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5, -columnspan => 2);

my $format_label = $frame->new_ttk__label(-text => 'Source Format');
$format_label->g_grid(-row => 3, -column => 0, -sticky => 'nw', -padx => 10, -pady => 5);

my $source_format = 'splashidvid';

my $radio_splashid = $frame->new_ttk__radiobutton(-text => "SplashID vID", -value => $source_format,
                                           -variable=> \$source_format);
$radio_splashid->g_grid(-row => 3, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);

my $radio_1password = $frame->new_ttk__radiobutton(-text => "1Password .1pif", -value => "1password",
                                             -variable=> \$source_format);
$radio_1password->g_grid(-row => 3, -column => 2, -sticky => 'nw', -padx => 10, -pady => 5);

my $radio_safewallet = $frame->new_ttk__radiobutton(-text => "SafeWallet XML", -value => "safewallet",
                                           -variable=> \$source_format);
$radio_safewallet->g_grid(-row => 3, -column => 3, -sticky => 'nw', -padx => 10, -pady => 5);

my $export_button = $frame->new_ttk__button(-text => 'Run Conversion',  -command => \&export);
$export_button->g_grid(-row => 4, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);
 
Tkx::MainLoop();

sub getSource {
  $opt_source = Tkx::tk___getOpenFile();
}

sub getTarget {
  $opt_target = Tkx::tk___getSaveFile(-initialfile => 'codebook.csv', -defaultextension => '.csv');
}

sub validate {
  my $message = "";
  unless($opt_source) {
    $message .= "Choose the directory to load Codebook databases from\n"; 
  }
  unless($opt_target) {
    $message .= "Choose the file to save entries to\n"; 
  }
  if($message) {
    Tkx::tk___messageBox(-message => "$message\n", -type => "ok");
    return 0;
  }
  return 1;
}

sub export {
  if(validate()) {
    if ($source_format eq 'splashidvid') {
      splashIdToStrip();
    } elsif ($source_format eq 'safewallet') {
      safeWalletToSTRIP();
    } else {
      onePasswordToStrip();
    }
    Tkx::tk___messageBox(-message => "Conversion complete!\n", -type => "ok");
  }
}

sub safeWalletToSTRIP {
  my @entries = ();
  my @fields = ();
  my $field_names = {};
  my $slurp_handle;
  unless(open($slurp_handle, "<", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }
  # binmode $slurp_handle;
  # slurp data into a string and squash any vertical tab control char (html-encoded) with a newline control char
  $/ = "";
  my $xml = <$slurp_handle>;
  # Transform thanks to @HiwayBK
  Encode::from_to($xml, 'UTF-16LE', 'utf8');
  # Regex format thanks to @SKradel
  $xml =~ s"\&#xB;"\&#xA;"gi;
  my $doc = XML::LibXML->load_xml(string => $xml, recover => 2) or die;
  my $isVersion3 = 0;
  my $root = $doc->documentElement();
  if (!defined($root)) {
    Tkx::tk___messageBox(-title => "Unable to read source file", -message => "SafeWallet XML export files are usually UTF-16LE, please check the file format at " . $opt_source . "\n", -type => "Dismiss");
    return;
  }
  my @nodes = $root->getElementsByTagName('T37');
  my $folder_tag_name = 'Folder';
  my $record_tag_name = 'Card';
  # if T37 tag is present, we are working with SafeWallet v3 export, update names used for key elements...
  if (scalar(@nodes) > 0) {
    $folder_tag_name = 'T3';
    $record_tag_name = 'T4';
  }
  foreach my $folder ($root->getElementsByTagName( $folder_tag_name )) {
    my $folder_name = $folder->getAttribute('Caption');
    foreach my $card ($folder->getChildrenByTagName( $record_tag_name )) {
      my $entry = safeWallet_entryForRecord(\$card, \@fields, \$field_names);
      # need to set the category name
      $entry->{'category'} = $folder_name;
      push(@entries, $entry);
    }
    # next let's check for T22 web login records
    foreach my $t22 ($folder->getChildrenByTagName('T22')) {
      my $entry = safeWallet_entryForRecord(\$t22, \@fields, \$field_names);
      # set the category name
      $entry->{'category'} = $folder_name;
      push(@entries, $entry);
    }
  }
  # check for T22 records wrapped in a T21 category
  foreach my $t21 ($root->getElementsByTagName('T21')) {
    my $t21_caption = $t21->getAttribute('Caption');
    foreach my $t22 ($t21->getChildrenByTagName('T22')) {
      my $entry = safeWallet_entryForRecord(\$t22, \@fields, \$field_names);
      $entry->{'category'} = $t21_caption;
      push(@entries, $entry);
    }
  }
  # check for Identity category (T39) for records
  foreach my $t39 ($root->getElementsByTagName('T39')) {
    my $t39_caption = $t39->getAttribute('Caption');
    foreach my $record ($t39->getChildrenByTagName('*')) {
      my $entry = safeWallet_entryForRecord(\$record, \@fields, \$field_names);
      $entry->{'category'} = $t39_caption;
      push(@entries, $entry);
    }
  }
  close($slurp_handle);
  print_csv(\@entries, \@fields, \$field_names);
}

sub safeWallet_entryForRecord {
  # my $card_ref  = $_[0];
  # my $card      = $$card_ref;
  # my $card_name = $card->getAttribute('Caption');
  # my $fields_ref  = $_[1];
  # my @fields      = @$fields_ref;
  # my $names_ref   = $_[2];
  # my $field_names = $$names_ref;
  my $card_ref  = $_[0];
  my $card      = $$card_ref;
  my $card_name = $card->getAttribute('Caption');
  # these two we want to update the originals by reference
  # so access with @$fields and $$field_names, respectively
  my $fields      = $_[1];
  my $field_names = $_[2];
  
  # set up the entry
  my $entry     = {
    'name'      => $card_name,
    'fields'    => {}
  };
  # the child property elements used to be called Property, now varying T* number types
  foreach my $property ($card->getChildrenByTagName('*')) {
    my $property_name = $property->getAttribute('Caption');
    # Have we already seen this field for the header row listing?
    my $field_key = lc($property_name);
    if (!contains($field_key, @$fields)) { 
      push(@$fields, $field_key);
      $$field_names->{$field_key} = $property_name;
    }
    # Add the value of this field (property) to the entry's fields (if it has any PCDATA)
    if (defined($property->textContent) && $property->textContent ne '') {
      $entry->{'fields'}->{$field_key} = $property->textContent;
    }
  }
  # this could be a web login (T22) record, look for those additional attributes on the node itself
  if ($card->nodeName() eq 'T22') {
    my @attributes = ( 'URL', 'Username', 'Password' );
    for my $attribute (@attributes) {
      my $value = $card->getAttribute($attribute);
      if (defined($value) && $value ne '') {
        # make sure there's a field name record in case we haven't already created one for this key
        my $field_key = lc($attribute);
        if (!contains($field_key, @$fields)) {
          push(@$fields, $field_key);
          $$field_names->{$field_key} = $attribute;
        }
        $entry->{'fields'}->{$field_key} = $value;
      }
    }
  }
  return $entry;
}

sub onePasswordToStrip {
  my @entries = ();
  my @fields  = ();
  my $fh;
	my $slurp_handle;
	
	unless(open($slurp_handle, "<:encoding(utf8)", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }

	# slurp it in once so we can scan for our record separator
	$/ = "";
	$_ = <$slurp_handle>;
	close($slurp_handle);
	# look for a pattern like this to get our record separator matches
	$_ =~ /\*\*\*[a-z0-9-]+\*\*\*/;
	# our record separator will be what was matched
	$/ = $&;
  
  unless(open($fh, "<:encoding(utf8)", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }

  while(<$fh>) {
    # There are odd noise lines between each entry, each the same:
    # ***5642bee8-a5ff-11dc-8314-0800200c9a66***
    # We'll just check for the first three asterisks and skip if detected.
    if ($_ =~ /^\*\*\*.*$/ or $_ =~ /^\s*$/ ) { next; }

		chomp;
    
    # http://stackoverflow.com/questions/6905164/perl-uncaught-exception-malformed-utf-8-character-in-json-string
    # decode wants a UTF-8 "binary" string, ie bytes
    my $json_bytes = encode('UTF-8', $_);
    my $row       = JSON->new->utf8->decode($json_bytes);
    # typeName: wallet.financial.CreditCard, split and take the last array element
    my @decimals  = split(/\./, $row->{'typeName'});

		# watch out for trash...
		my $trashed = $row->{'trashed'};
		if (defined($trashed) && $trashed == 1) {
			next;
		}

		# figure out a name for the entry, in case it doesn't have one
		my $entry_name = $row->{'title'};
		if ($entry_name eq '' or $entry_name =~ /^\s*$/) {
		  $entry_name = 'Untitled entry';	
		}
    my $entry     = {
      'name'      => $entry_name,
      'category'  => $decimals[-1],
      'fields'    => {}
    };
    my $idx = 0;
    # secureContents is another hash, describing the entry fields,
    # and most of these are empty, which is just delightful.
    foreach(keys %{$row->{'secureContents'}}) {
      my $name = $_;
      my $value = $row->{'secureContents'}->{$name};
      # add the field to our list if it's not in there already (but ignore the 'fields' name, holding an inner set of fields)
      if(!contains($name, @fields) && $name ne 'fields' && $name ne 'passwordHistory') {
         push(@fields, $name);
      }
      # add it to the entry if it's not blank
      if (defined($value) && $value ne '') {
        # if it's named 'fields' we need to go one level deeper
        if ($name eq 'fields') {
          foreach(@$value) {
            # each element of the array is hash, we want the name and value keys
            # see if this field name is in @fields...
            if (!contains($_->{'name'}, @fields)) { push(@fields, $_->{'name'}); }
            # if it has a value, add it to our set for the entry
            if (defined($_->{'value'}) && $_->{'value'} ne '') {
              $entry->{'fields'}->{$_->{'name'}} = $_->{'value'};
            }
          }
        }
        else {
          # ignore passwordHistory array
          if ($name ne 'passwordHistory') {
            $entry->{'fields'}->{$name} = $value;
          }
        }
      }   
    }
    push(@entries, $entry);
    $idx++;
  }
  close($fh);
  print_csv(\@entries, \@fields);
}

sub splashIdToStrip {
  my $categories = {};
  my @entries = ();
  my @fields = ("Note");
  my $idx = 0;
  my $fh;
  my $csv = Text::CSV->new({binary => 1});
  
  unless(open($fh, "<", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }

  my $key; # save reference to category
  while(my $rowref = $csv->getline($fh)) {

       if($idx++ < 2) {next;};
       my @row = @$rowref;

       if($row[0] eq 'T') {
         # if the first column contains a T, it's a category definition, e.g.
         # T,21,Web Logins,Description,Username,Password,URL,Field 5,Field 6,Field 7,Field 8,Field 9,Date Mod,4,
         $key = $row[1];
         my @cfields = @row[4..11];
         $categories->{$key} = {
           "id"       => $row[1],
           "name"     => $row[2],
           "fields"   => \@cfields
         };

         foreach(@cfields) {
           if(defined($_) && !contains($_, @fields)) {
             push(@fields, $_);
           } 
         } 
       }  else {
         ##  entry row
         my $ckey = $row[1];
         unless(exists($categories->{$ckey})) { $ckey = $key; } # if category key is not found, use the last category imported
         my $efields = {};
         my $i = 0;
         my @cfields = @{$categories->{$ckey}->{"fields"}};
         foreach(@row[3..@cfields]) {
           my $name = $cfields[$i++];
           if(defined && defined($name) && $name ne '') {
             $efields->{$name} = $_;
           }
         }
         $efields->{"Note"} = $row[-1]; # last field in row is the note
				 # figure out a name for the entry, in case it doesn't have one
				 my $entry_name = $row[2];
				 if ($entry_name eq '' or $entry_name =~ /^\s*$/) {
				   $entry_name = 'Untitled entry';	
				 }
         my $entry = { 
           "name" => $entry_name,
           "category" => $categories->{$ckey}->{"name"},
           "fields" => $efields
         };
         push(@entries, $entry);
       }
  }
  close($fh);
  print_csv(\@entries, \@fields);
}

sub contains {
  my $val = shift;
  my %vals = map {$_=>1} @_;
  return (exists($vals{$val})) ? 1 : 0;
}

# print_csv(@entries, @fields);
sub print_csv {
  my $entries_ref = $_[0];
  my $fields_ref = $_[1];
  my $names_ref = $_[2];

  my @entries = @$entries_ref;
  my @fields = @$fields_ref;
  my $field_names;
  if (defined($names_ref)) {
    $field_names = $$names_ref;
  }
  my $fh;
  my $csv = Text::CSV->new({binary => 1, eol=>"\n"});
  
  # FIXME: consider turning this off to preserve user ordering once we're done testing
  @fields = sort(@fields);
  unless(open($fh, ">:encoding(utf8)", $opt_target)) {
    Tkx::tk___messageBox(-message => "Can't open target file!\n", -type => "ok");
    return;
  }
  
  my @header = ("Category", "Entry");
  foreach(@fields) {
    if(defined && $_ ne '') {
      if (defined($field_names)) {
        push(@header, $field_names->{$_});
      } else {
        push(@header, $_);
      }
    }
  }

  $csv->print($fh, \@header);
  foreach(@entries) {
    my $entry = $_;
    my @row = ($entry->{"category"}, $entry->{"name"});
    foreach(@fields) {
      if(defined && $_ ne '') {
        if(exists($entry->{"fields"}->{$_})) {
					my $output = $entry->{"fields"}->{$_};
					$output =~ s/\|/\\|/;
					# escape any pipe characters with \ for STRIP CSV formatting
          push(@row,$output);
        } else {
          push(@row, "");
        }
      }
    } 
    $csv->print($fh, \@row);
  }
  close($fh);
}
