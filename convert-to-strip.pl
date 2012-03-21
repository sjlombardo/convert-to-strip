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
use Text::CSV_PP;
use JSON;
use Data::Dumper;

use vars qw($opt_source $opt_target $file);

my $IS_AQUA = Tkx::tk_windowingsystem() eq "aqua";

my $mw = Tkx::widget->new(".");
$mw->g_wm_title("SplashID to Strip Converter");

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

my $export_button = $frame->new_ttk__button(-text => 'Run Conversion',  -command => \&export);
$export_button->g_grid(-row => 4, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);
 
Tkx::MainLoop();

sub getSource {
  $opt_source = Tkx::tk___getOpenFile();
}

sub getTarget {
  $opt_target = Tkx::tk___getSaveFile(-initialfile => 'strip.csv', -defaultextension => '.csv');
}

sub validate {
  my $message = "";
  unless($opt_source) {
    $message .= "Choose the directory to load Strip databases from\n"; 
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
    } 
    else {
      onePasswordToStrip();
    }
    Tkx::tk___messageBox(-message => "Conversion complete!\n", -type => "ok");
  }
}

sub onePasswordToStrip {
  my @entries = ();
  my @fields  = ();
  my $fh;
  
  unless(open($fh, "<:encoding(utf8)", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }
  while(<$fh>) {
    # There are odd noise lines between each entry, each the same:
    # ***5642bee8-a5ff-11dc-8314-0800200c9a66***
    # We'll just check for the first three asterisks and skip if detected.
    if ($_ =~ /^\*\*\*.*$/) { next; }
    my $row       = JSON->new->utf8->decode($_);
    # typeName: wallet.financial.CreditCard, split and take the last array element
    my @decimals  = split(/\./, $row->{'typeName'});
    my $entry     = {
      'name'      => $row->{'title'},
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
      if(!contains($name, @fields) && $name ne 'fields') {
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
          $entry->{'fields'}->{$name} = $value;
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
  
  unless(open($fh, "<:encoding(utf8)", $opt_source)) {
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
         my $entry = { 
           "name" => $row[2],
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

  my @entries = @$entries_ref;
  my @fields = @$fields_ref;
  my $fh;
  my $csv = Text::CSV->new({binary => 1, eol=>"\n"});
  
  @fields = sort(@fields);
  unless(open($fh, ">", $opt_target)) {
    Tkx::tk___messageBox(-message => "Can't open target file!\n", -type => "ok");
    return;
  }
  
  my @header = ("Category", "Entry");
  foreach(@fields) {
    if(defined && $_ ne '') { push(@header, $_) };
  }

  $csv->print($fh, \@header);
  foreach(@entries) {
    my $entry = $_;
    my @row = ($entry->{"category"}, $entry->{"name"});
    foreach(@fields) {
      if(defined && $_ ne '') {
        if(exists($entry->{"fields"}->{$_})) {
          push(@row,$entry->{"fields"}->{$_});
        } else {
          push(@row, "");
        }
      }
    } 
    $csv->print($fh, \@row);
  }
  close($fh);
}
