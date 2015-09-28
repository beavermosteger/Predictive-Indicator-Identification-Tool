#!/usr/bin/perl

# Copyright (C) 2015 Brian Spargur
# Copyright (C) 2015 Kevin Spargur

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License Version 2 as
# published by the Free Software Foundation.  You may not use, modify or
# distribute this program under any other version of the GNU General
# Public License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict;
use warnings;
use Time::Piece;
use Time::Seconds;
use Data::Dumper;  # print Dumper($foo);
use utf8;
use open ':encoding(utf8)';
use Encode;
use File::Basename;
use Getopt::Long;
use File::Copy;

my $error_file;
my $input_directory;
my $prefix;
my $verbose;
my $help;
my $datevar;
my $master;
my $target_file;

GetOptions ("date=i" => \$datevar,
			"log=s" => \$error_file,
			"master=s" => \$master,
			"input=s" => \$input_directory,
			"help" => \$help,
			"prefix=s" => \$prefix,
			"verbose" => \$verbose);  # flag
			
my $prog = basename($0);
sub usage{
    warn <<"EOF";

USAGE
  $prog -date <date>

DESCRIPTION
  Adds the daily summary file for the date given to the master summary file.  
  Must be given a date value, other values have defaults

OPTIONS
  -help           	Print this help message.  Not sure why this is even
			here to be honest this stuff is very confusing
  -verbose		Verbose mode, really, really verbose
  -input	dir	Read input from specified directory.  Defaults to
			"./1sources
  -master	file	Master summary file.  Defaults to
			"../2word_metrics/master_summaries/master_summary"
  -date		date	Date to grab source files from e.g. 20131020
  -log		file	File to log errors to (not implemented)
  -prefix	string	Prefix for each output (bucket) file.
			defaults to "word_metrics_"


OPERANDS
  date          Date to grab source files from e.g. 20131020

EXAMPLES
  $prog -date 20131020
  $prog -v -d 20131020
  $prog -h

EOF

exit 0;
}


usage() if $help;
warn "\nError: no date defined!\n" and usage() unless $datevar;

$input_directory = "../2word_metrics/metrics_summaries" unless $input_directory;
$error_file = "../2word_metrics/errors.txt" unless $error_file;
$prefix = "word_metrics_" unless $prefix;
$master = "../2word_metrics/master_summaries/master_summary" unless $master;


##FUNCTIONS########################################

sub get_files {
    my $path = shift;
    my @files;

    opendir (DIR, $path) or die "Unable to open $path: $!";
    my @all_files =
        # Third: Prepend the full path
        map { $path . '/' . $_ }
        # Second: take out '.' and '..'
        grep { !/^\.{1,2}$/ }
        # First: get all files
        readdir (DIR);
    closedir (DIR);

    for (@all_files) {
        if (-d $_) {
            push @files, get_files ($_);
        }
        else{
                push @files, $_;
        }
    }
    # NOTE: we're returning the list of files
    return @files;
}

sub get_file_size {
        my $file = shift;
        my $size;

        $size = `wc -l $file | awk '{print \$1}'`;

        return $size;
}

sub get_count {
        my $file = shift;
        my $count;

        $count = `head -n1 $file`;
        $count =~ s/\s+// if $count;


        return $count;
}

sub grep_file {
        my $file = shift;
        my $word = shift;
        my $output_directory = shift;
        my $result;

        open(my $handle,'>:raw:perlio:utf8',$output_directory."/pattern.tmp") or die("Can't open pattern.tmp");
        print $handle "^$word ";
        close $handle;
        #Clean up word to avoid shell expansion
        if($word=~/.*'.*/){
                #print "Running: grep -m1 \"^$word \" $file\n";
                $result = `grep -m1 -f "$output_directory/pattern.tmp" $file`;
        }
        else{
                #print "Running: grep -m1 '^$word ' $file\n";
                $result = `grep -m1 -f "$output_directory/pattern.tmp" $file`;
	}

        if($result){
                #print "INSIDE: result=$result\n";
                $result = (split(/ /,$result,2))[1];
        }

        unlink "$output_directory/pattern.tmp";
        return $result;
}
####END OF FUNCTIONS######################################

my @possible_inputs = get_files($input_directory);

#print @possible_inputs;

if (($target_file) = grep /$datevar/, @possible_inputs) {
    print "$prog: Found match: $target_file\n";
}
else{
    die "$prog: Unable to find input file matching $datevar\n";
}

my $total_time = time();

my $no_master = 0;

open (my $MASTER,'<:raw:perlio:utf8',"$master") or $no_master = 1;
open (my $DAILY,'<:raw:perlio:utf8',"$target_file") or die("Can't open $target_file");
open (my $MASTERTMP,'>:raw:perlio:utf8',"$master.tmp") or die("Can't open $master.tmp");


my $count =0;

#keep this outside the loop so we can use it when backing up master near the
# end of the script
my $old_date;

#Get and verify count
$count = <$DAILY>;
chomp($count);
if($count!~/^\d+$/){
	die "$prog: Error retrieving count from $target_file, pulled \"$count\"\n";
}

#Take care of the headers for the master file...
#if no master file we need to make one
if($no_master == 1){
    print $MASTERTMP "######HEADER DATA######################\n";
    print $MASTERTMP "#DATE: $datevar\n";
    print $MASTERTMP "#COUNT: $count\n";
    print $MASTERTMP "#######################################\n";
}
else{
    #Discard first header line
    <$MASTER>;
    $old_date = <$MASTER>;
    $old_date = (split(/\s+/,$old_date))[1];
    chomp($old_date);
    print "$prog: $old_date > $datevar?\n" if $verbose;
    if($old_date >= $datevar){
    #if(1 >= 10){
        die "$prog: Error header date in master ($old_date) is newer than summary ($datevar), exiting...\n";
    }
    my $old_count = <$MASTER>;
    $old_count = (split(/\s+/,$old_count))[1];
    chomp($old_count);
    $count = $count + $old_count;
    print $MASTERTMP "######HEADER DATA######################\n";
    #By virtue of our previous test we can assume this is the most recent
    #date we have seen
    print $MASTERTMP "#DATE: $datevar\n";
    print $MASTERTMP "#COUNT: $count\n";
    print $MASTERTMP "#######################################\n";

    #Get rid of the last of the header lines to align the pointer
    <$MASTER>;
}

my $f1;
$f1 = <$MASTER> unless $no_master ==1;
chomp($f1) if defined($f1);
my $f2 = <$DAILY>;
chomp($f2) if $f2;

my $line_counter = 0;
my $report_limit = 1000000;
my $bucket_time = time();

while (defined($f1) or defined($f2)) {
    if($line_counter > $report_limit){
        print "$prog: Reached $report_limit, duration in seconds:".(time()-$bucket_time)."\n";
        $bucket_time = time();
        $line_counter = 0;
    }    

    if (defined($f1) and defined($f2) and ((split(/\s/,$f1))[0]) eq ((split(/\s/,$f2))[0])) {
        #Merge the two entries using MASTER as the base
        my @tmp = split(/\s/,$f2);
	#get rid of the word from $f2 we only want counts
        my $test = shift @tmp;
        $f1 = $f1." ".join(" ",@tmp);
        
        #Write to the file
        print $MASTERTMP "$f1\n";
        $f1 = <$MASTER>;
        chomp($f1) if defined($f1);
        $f2 = <$DAILY>;
        chomp($f2) if defined($f2);
    }
    elsif ((defined($f1) and defined($f2) and ((split(/\s/,$f1))[0]) lt ((split(/\s/,$f2))[0])) or (defined($f1) and (! defined($f2)))){
        print $MASTERTMP "$f1\n";
        $f1 = <$MASTER>;
        chomp($f1) if defined($f1);
    }
    else {
        print $MASTERTMP "$f2\n";
        $f2 = <$DAILY>;
        chomp($f2) if defined($f2);
    }

    $line_counter+=1;
}


close($MASTER) unless $no_master == 1;
close($DAILY);
close($MASTERTMP);


move($master,"$master.$old_date") unless $no_master ==1;
move("$master.tmp",$master);

	
print "$prog: Total time in seconds: ".(time()-$total_time)."\n";

