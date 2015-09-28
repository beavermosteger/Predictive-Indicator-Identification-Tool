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
use DateTime;
use DateTime::Format::Duration;
use File::Basename;
use Getopt::Long;
use List::MoreUtils qw(none uniq);


binmode(STDOUT, ":utf8");

my $output_directory;
my $outfile;
my $help;
my $verbose;
my $master_summary_file;


my $outfile_default="./3baselines/baseline_".DateTime->now->strftime('%Y%m%d').".txt";

GetOptions (        "master=s" => \$master_summary_file,
		   "outfile=s" => \$outfile,
			"help" => \$help,
		     "verbose" => \$verbose);  # flag
			
my $prog = basename($0);
sub usage{
    warn <<"EOF";

USAGE
  $prog -m file -o file

DESCRIPTION
  Calculate deltas between actuals and baseline.

OPTIONS
  -h            Print this help message
  -v		Verbose mode
  -o    file    Dump output to specifed file. Defaults to
                "$outfile_default"
  -m	file	Master summary file

OPERANDS
  file          A path name of a file.

EXAMPLES
  $prog -m master_summary.txt -o $outfile_default
  $prog -v -m master_summary.txt -o $outfile_default
  $prog -h

EXIT STATUS
  0     Successful completion
  >0    An error occurred

EOF

exit 0;
}

usage() and die unless $master_summary_file;
$outfile = $outfile_default unless $outfile;


sub total{
        my($data) = @_;
        if (not @$data) {
                die("Empty array\n");
        }
        my $total = 0;
        foreach (@$data) {
                $total += $_;
        }
        return $total;
}


sub flush {
   my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h);
}


sub get_files {
    my $path = shift;
	my @files;

    opendir (DIR, $path) or die "$prog: Unable to open $path: $!";
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

	my $result;


	open(my $handle,'>:raw:perlio:utf8',$output_directory."/pattern.tmp") or die("$prog: Can't open pattern.tmp");
	print $handle "^$word ";
	close $handle;
	#Clean up word to avoid shell expansion
	
	if($word=~/.*'.*/){
		$result = `grep -m1 -f $output_directory."/pattern.tmp" $file`;
	}
	else{
		$result = `grep -m1 -f "$output_directory/pattern.tmp" $file`;
	}
	
	if($result){
		$result = (split(/ /,$result,2))[1];
	}

	return $result;
}


my $dict_time = time();

open(my $MASTERSUM,'<:raw:perlio:utf8',"$master_summary_file") or die("$prog: Can't open $master_summary_file");

print "$prog: output file: ".$outfile."\n";

open(my $outhandle,'>:raw:perlio:utf8',$outfile) or die("$prog: Can't open $outfile");
#print $outhandle "WORD COUNT MEAN SUM VARIANCE STANDARD_DEVIATION MIN MAX SAMPLE_RANGE MEDIAN MODE HARMONIC_MEAN GEOMETRIC_MEAN\n";
print $outhandle "WORD COUNT AVERAGE STANDARD_DEVIATION\n";

#Header in master summary appears as follows:
######HEADER DATA######################
#DATE: 20131112
#COUNT: 4176
#######################################

#Strip and parse header data
<$MASTERSUM>;
my $master_date = <$MASTERSUM>;
$master_date = (split(/\s/,$master_date))[1];
my $master_count = <$MASTERSUM>;
$master_count = (split(/\s/,$master_count))[1];
my $test=<$MASTERSUM>;




#Hacked up to use the total which we grab just above
sub average{
        my ($data) = @_;
        if (not @$data) {
                die("Empty array\n");
        }
        my $total = 0;
        foreach (@$data) {
                $total += $_;
        }
        my $average = $total / $master_count;
        return $average;
}
sub stdev{
        my($data) = @_;
        if(@$data == 1){
                return 0;
        }
        my $average = &average($data);
        my $sqtotal = 0;
        foreach(@$data) {
                $sqtotal += ($average-$_) ** 2;
        }
        my $std = ($sqtotal / (@$data-1)) ** 0.5;
        return $std;
}
###########################


my $line_counter = 0;
my $report_limit = 1000000;
my $loop_time = time();


while(my $line = <$MASTERSUM>){
	if($line_counter > $report_limit){
		print "$prog: Reached $report_limit, duration in seconds:".(time()-$loop_time)."\n";
		$loop_time = time();
		$line_counter = 0;
	}
	$line_counter+=1;



	#my $start_time = time();
	my @elements = split(/\s/,$line);
	my $word = shift @elements;

        #my $stat = Statistics::Descriptive::Full->new();
	#my $total_samplings = scalar @elements;

	#print "BEFORE WHILE: $total_samplings < $master_count ?\n";
	#while($total_samplings < $master_count){
	#	$total_samplings+=1;
	#	push(@elements,0);
	#}
	#print "AFTER WHILE: $total_samplings < $master_count ?\n";
	
	#die;

	#for my $i (@elements){
	#	$total_samplings+=1;
	#	$stat->add_data($i);
	#}
	#while($total_samplings < $master_count){
	#	$total_samplings+=1;
	#	$stat->add_data(0);
	#}

	#my $stat_count = (defined($stat->count())? $stat->count():"UNDEF");
	#my $stat_mean = (defined($stat->mean())? $stat->mean():"UNDEF");
	#my $stat_sum = (defined($stat->sum())? $stat->sum():"UNDEF");
	#my $stat_variance = (defined($stat->variance())? $stat->variance():"UNDEF");
	#my $stat_standard_deviation = (defined($stat->standard_deviation())? $stat->standard_deviation():"UNDEF");
	#my $stat_min = (defined($stat->min())? $stat->min():"UNDEF");
	#my $stat_max = (defined($stat->max())? $stat->max():"UNDEF");
	#my $stat_sample_range = (defined($stat->sample_range())? $stat->sample_range():"UNDEF");
	#my $stat_median = (defined($stat->median())? $stat->median():"UNDEF");
	#my $stat_mode = (defined($stat->mode())? $stat->mode():"UNDEF");
	#my $stat_harmonic_mean = (defined($stat->harmonic_mean())? $stat->harmonic_mean():"UNDEF");
	#my $stat_geometric_mean = (defined($stat->geometric_mean())? $stat->geometric_mean():"UNDEF");

	#my $line = "$word $stat_count $stat_mean $stat_sum $stat_variance $stat_standard_deviation $stat_min $stat_max $stat_sample_range $stat_median $stat_mode $stat_harmonic_mean $stat_geometric_mean";
	my $count = &total(\@elements);
	#my $tmp = $master_count;
	my $average = &average(\@elements);
	my $stddev = &stdev(\@elements);
	my $line ="$word $count $average $stddev";

	$line =~ s/[\n\r]//g;
	print $outhandle "$line\n";

}
print "$prog: Dictionary building time in seconds: ".(time()-$dict_time)."\n";

close($outhandle);
