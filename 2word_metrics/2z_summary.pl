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


my $output_directory1;
my $output_directory2;
my $error_file;
my $input_directory;
my $prefix;
my $verbose;
my $help;
my $datevar;

GetOptions ("date=i" => \$datevar,
			"l=s" => \$error_file,
			"id=s" => \$input_directory,
			"o1=s" => \$output_directory1,
			"o2=s" => \$output_directory2,
			"h" => \$help,
			"prefix=s" => \$prefix,
			"v" => \$verbose);  # flag
		
	
my $prog = basename($0);
sub usage{
    warn <<"EOF";


DESCRIPTION

Resolves excessive daily increase to processing times 

EOF

exit 0;
}


usage() if $help;
warn "\nError: no date defined!\n" and usage() unless $datevar;

$input_directory = "./2word_metrics/metrics_by_day" unless $input_directory;
$output_directory1 = "./2word_metrics/metrics_summaries" unless $output_directory1;
$error_file = "./2word_metrics/errors.txt" unless $error_file;
$prefix = "word_metrics_" unless $prefix;

my $total_time = time();
$datevar =~ /(\d{4})(\d{2})(\d{2})/;
my $year = $1;
my $month= $2;
my $day  = $3;

print "Year: $year Month: $month Day: $day\n" if $verbose;

sub get_files {
	my $path = shift;
	my $filter = shift;
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
            		# Add all of the new files from this directory
            		# (and its subdirectories, and so on... if any)
            		push @files, get_files ($_, $filter);
        	}
		else{
			if(/.*$filter.*/){
				print "FOUND: $_\n" if $verbose;
				push @files, $_;
			}
		}
 	}
    # NOTE: we're returning the list of files
    return @files;
}


my @list_of_files = get_files($input_directory,$datevar);

print join("\n",@list_of_files)."\n" if $verbose;

my %dictionary;
my $dict_time = time();

for my $file (@list_of_files){
	print "Reading: $file\n" if $verbose;
	open(my $handle,'<:raw:perlio:utf8',"$file") or die("Can't open $file");
	my @inputs = <$handle>;
	close($handle);
	for my $line (@inputs){
		my ($word,$count) = split(/ /,$line);
		$count =~ s/\s//g;
                next unless $count =~/^\d+$/;
		
		push(@{$dictionary{$word}},$count);
	}
	
}
print "$prog: Dictionary building time in seconds: ".(time()-$dict_time)."\n";

mkdir $output_directory1."/".$year unless (-e $output_directory1."/".$year);
mkdir $output_directory1."/".$year."/".$month unless (-e $output_directory1."/".$year."/".$month);
my $output_file = $output_directory1."/".$year."/".$month."/word_metrics_summary_$datevar.txt";


my $write_time = time();

if(!keys %dictionary){
	#No words in dictionary, dont write anything
	print "$prog: no 'words' found to add to $output_file, skipping...\n";
}
else{
	open (my $handle,'>:raw:perlio:utf8',"$output_file") or die("Can't open $output_file");
	print $handle ($#list_of_files + 1)."\n";
	print $#list_of_files."\n" if $verbose;

	for my $key (sort keys %dictionary){
		print $handle $key." ".join(" ",@{$dictionary{$key}})."\n";
		print $key." ".join(" ",@{$dictionary{$key}})."\n" if $verbose;
	}
}

print "$prog: Write time in seconds: ".(time()-$write_time)."\n";
print "$prog: Total time in seconds: ".(time()-$total_time)."\n";

