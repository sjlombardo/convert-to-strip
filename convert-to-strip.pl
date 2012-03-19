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
#use Data::Dumper;

use vars qw($opt_source $opt_target $file);

my $IS_AQUA = Tkx::tk_windowingsystem() eq "aqua";

my $mw = Tkx::widget->new(".");
$mw->g_wm_title("SplashID to Strip Converter");

my $frame = $mw->new_frame();
$frame->g_pack(-anchor=>'center', -padx => 20, -pady => 20);

my $source_button = $frame->new_ttk__button(-text => 'Source File',  -command => \&getSource);
$source_button->g_grid(-row => 1, -column => 0, -sticky => 'nw', -padx => 10, -pady => 5);

my $directory_entry = $frame->new_ttk__entry(-width => 60, -textvariable => \$opt_source);
$directory_entry->g_grid(-row => 1, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);

my $file_button = $frame->new_ttk__button(-text => 'Save As',  -command => \&getTarget);
$file_button->g_grid(-row => 2, -column => 0, -sticky => 'nw', -padx => 10, -pady => 5);

my $file_entry = $frame->new_ttk__entry(-width => 60, -textvariable => \$opt_target);
$file_entry->g_grid(-row => 2, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);

my $export_button = $frame->new_ttk__button(-text => 'Run Conversion',  -command => \&export);
$export_button->g_grid(-row => 3, -column => 1, -sticky => 'nw', -padx => 10, -pady => 5);
 
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
    splashIdToStrip();
    Tkx::tk___messageBox(-message => "Conversion complete!\n", -type => "ok");
  }
}


sub splashIdToStrip {
  my $categories = {};
  my @entries = ();
  my @fields = ();
  my $idx = 0;
  my $fh;

  my $csv = Text::CSV->new({binary => 1});
  
  unless(open($fh, "<", $opt_source)) {
    Tkx::tk___messageBox(-message => "Can't open source file " . $opt_source . "!\n", -type => "ok");
    return;
  }

  while(my $rowref = $csv->getline($fh)) {

       if($idx++ < 2) {next;};
       my @row = @$rowref;


       if($row[0] eq 'T') {
         # if the first column contains a T, it's a category definition, e.g.
         # T,21,Web Logins,Description,Username,Password,URL,Field 5,Field 6,Field 7,Field 8,Field 9,Date Mod,4,
         my $key = $row[1];
         my @cfields = @row[4..11];
         $categories->{$key} = {
           "id"       => $row[1],
           "name"     => $row[2],
           "fields"   => \@cfields
         };

         foreach(@row[4..11]) {
           if(!contains($_, @fields)) {
             push(@fields, $_);
           } 
         } 
       }  else {
         ##  entry row
         my $ckey = $row[1];
         my $efields = {};
         my $i = 0;
         foreach(@row[3..10]) {
           my $name = @{$categories->{$ckey}->{"fields"}}[$i++];
           $efields->{$name} = $_;
         }
         my $entry = { 
           "name" => $row[2],
           "category" => $categories->{$ckey}->{"name"},
           "fields" => $efields
         };
         push(@entries, $entry);
       }
  }
  close($fh);

  @fields = sort(@fields);

  unless(open($fh, ">", $opt_target)) {
    Tkx::tk___messageBox(-message => "Can't open target file!\n", -type => "ok");
    return;
  }

  my @header = (("Category", "Entry"), @fields);
  $csv->print($fh, \@header);
   
  foreach(@entries) {
    my $entry = $_;
    my @row = ($entry->{"category"}, $entry->{"name"});
    foreach(@fields) {
      if(exists($entry->{"fields"}->{$_})) {
        push(@row,$entry->{"fields"}->{$_});
      } else {
        push(@row, "");
      }
    } 
    $csv->print($fh, \@row);
  }

  close($fh);
}

sub contains {
  my $val = shift;
  my %vals = map {$_=>1} @_;
  return (exists($vals{$val})) ? 1 : 0;
}
