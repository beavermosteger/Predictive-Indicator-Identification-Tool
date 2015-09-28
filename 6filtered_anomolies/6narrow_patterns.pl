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
use Statistics::Descriptive;
use List::MoreUtils 'none';
use open ':encoding(utf8)';


binmode(STDOUT, ":utf8");

my $acceptable_deviation;
my $input_directory;
my $input_file;
my $output_directory;
my $output_file;
my $help;
my $verbose;
my $prog = basename($0);

GetOptions ("deviation=i" => \$acceptable_deviation,
			"i=s" => \$input_file,
			"id=s" => \$input_directory,
			"od=s" => \$output_directory,
			"o=s" => \$output_file,
			"h" => \$help,
			"v" => \$verbose);  # flag
			
sub usage{
    warn <<"EOF";

DESCRIPTION
	Does correlation to improve fidelity

EOF

exit 0;
}

$output_directory = "./6filtered_anomolies" unless $output_directory;
$output_file = "filtered_".$input_file unless $output_file;
my $full_out = $output_directory."/".$output_file;

warn "\nError: no input directory defined!\n" and usage() unless $input_directory;
warn "\nError: no input file defined!\n" and usage() unless $input_file;
warn "\nError: no acceptable deviation defined!\n" and usage() unless $acceptable_deviation;
warn "\nError: no output file defined!\n" and usage() unless $output_file;
warn "\nError: no output directory defined!\n" and usage() unless $output_directory;


			
if($help){
	usage();
}

my $load_time = time();


open (my $handle_out,'>',$output_directory."/".$output_file) or die("Can't open $output_file");
open (my $handle_in,'<',$input_directory."/".$input_file) or die("Can't open $input_file");
my @inputs = <$handle_in>;
close($handle_in);
chomp(@inputs);
print "$prog: Loaded inputs from $input_file, duration in seconds:".(time()-$load_time)."\n";

my @outputs;

my $line_counter = 0;
my $report_limit = 100000000;
my $loop_time = time();

while(my $line = shift @inputs){
	if ($line =~ /^#/){ next; }
	print $line."\n" if $verbose;
	
	my $stamp = (split('_to_',(split(/ /,$line))[3]))[0];
	
	my $stamp_in_seconds = Time::Piece->strptime($stamp,'%Y%m%d-%H%M%S')->epoch;
	
	for my $line2 (@inputs){
		if($line_counter > $report_limit){
                        print "$prog: Reached $report_limit, duration in seconds:".(time()-$loop_time)."\n";
                        $loop_time = time();
                        $line_counter = 0;
                }
                $line_counter+=1;

		my $stamp2 = (split('_to_',(split(/ /,$line2))[3]))[0];
		my $stamp_in_seconds2 = Time::Piece->strptime($stamp2,'%Y%m%d-%H%M%S')->epoch;
		
		my $threshold = 86400 * $acceptable_deviation;
		if(abs($stamp_in_seconds - $stamp_in_seconds2) <= $threshold){
			print $stamp." within $acceptable_deviation day(s) of ".$stamp2."!\n" if $verbose;
			print $line."\n" if $verbose;
			print $handle_out $line."\n";
		}
	}	
}
close($handle_out);

$load_time = time();

system("sort -S 3.5G -u $full_out -o $full_out");

print "$prog: Sort and unique of $output_file, duration in seconds:".(time()-$load_time)."\n";
