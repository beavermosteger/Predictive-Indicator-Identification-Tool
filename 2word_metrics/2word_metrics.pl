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
my $error_file;
my $input_directory;
my $prefix;
my $verbose;
my $help;
my $datevar;
my $bucket_size;

GetOptions ("date=i" => \$datevar,
			"log=s" => \$error_file,
			"bucket=i" => \$bucket_size,
			"input=s" => \$input_directory,
			"output=s" => \$output_directory1,
			"help" => \$help,
			"prefix=s" => \$prefix,
			"verbose" => \$verbose);  # flag
			
my $prog = basename($0);
sub usage{
    warn <<"EOF";

USAGE
  $prog -date <date>

DESCRIPTION
  Takes source data and creates interval or "bucket" files in the output
  directory.  Must be given a date value, other values have defaults

OPTIONS
  -help           	Print this help message.  Not sure why this is even
			here to be honest this stuff is very confusing
  -verbose		Verbose mode, really, really verbose
  -output	dir	Dump output to specifed directory.  Defaults to
			"./2word_metrics/metrics_by_day"
  -input	dir	Read input from specified directory.  Defaults to
			"./1sources
  -bucket	integer	Size of interval in minuts.  Make this divide evenly
			into the day.  Defaults to 10
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

$input_directory = "./1sources" unless $input_directory;
$output_directory1 = "./2word_metrics/metrics_by_day" unless $output_directory1;
$error_file = "./2word_metrics/errors.txt" unless $error_file;
$prefix = "word_metrics_" unless $prefix;
$bucket_size = 10 unless $bucket_size;


#modify record indicator
$/ = "KPBLOCK\r\n";

#Duration of how many 'minutes' in each bucket
#Make it divide evenly into the day or it will become an issue later

my @AoH;

#convert bucket_size to seconds
my $bucket_in_seconds = $bucket_size * 60;
my $seconds_in_day = 86400;

$#AoH = int($seconds_in_day / $bucket_in_seconds);


print "Need $#AoH buckets\n" if $verbose;
#die;


my %dictionary;
my $total_time = time();
my $dict_time = time();

my $tweet_collection = "twitter_stream_".$datevar.".txt";
open (my $tweet_handle,'<:raw:perlio:utf8',"$input_directory/$tweet_collection") or die("Can't open $input_directory/$tweet_collection");
my @input = <$tweet_handle>;
close($tweet_handle);

my $count =0;

while (my $line = shift @input) {
	#chomp;
	#my $line = $_;
	$line =~ s/\s+/ /g;
	#print "LINE: $line\n";
	my ($loose_time,$id,$username,$tweet) = split(/ /,$line,4); 
	
	#remove ':' after username
	chop($username);
	my $t;
	eval{
		$loose_time =~ s/[^[:ascii:]]//g;
		$t = Time::Piece->strptime($loose_time,"%Y%m%d-%H:%M:%S");
	};
	if ( my $err = $@ ) {
		print "Could not calculate time for: |".$loose_time."|\n";
		print "Died on |".$line."|\n";
		#print "Continuing...\n";
		die;
	}
	
	#Collection for time calcs
	my $hours = $t->hour;
	my $minutes = $t->min;
	my $seconds = $t->sec;
	
	my $seconds_into_day = ($hours * 60 * 60) + ($minutes * 60) + $seconds;
	#print "Seconds into day: $seconds_into_day\n";
	my $destination_bucket = int(($seconds_into_day / $seconds_in_day) * $#AoH);
	#print "Goes in bucket: $destination_bucket\n";
	
	for my $word (split(/ /,$tweet)){
		$word =~ s/\s//;
		$word =~ s/KPBLOCK//;
		
		if(exists $AoH[$destination_bucket]{$word}){
			$AoH[$destination_bucket]{$word}++;
		}
		else{
			$AoH[$destination_bucket]{$word} = 1; 
		}
	}
	
}

print "$prog: Dictionary building time in seconds: ".(time()-$dict_time)."\n";


my $t = Time::Piece->strptime(($datevar."-00:00:00"),"%Y%m%d-%H:%M:%S");

#$bucket_in_seconds
#strftime('%Y%m%d %H:%M:%S')

my $bucket_time = time();

unless(-e "$output_directory1"){
	mkdir "$output_directory1";
}

for my $bucket ( @AoH ) {
	my $bucket_lower = $t->strftime('%Y%m%d-%H%M%S');
	my $temptime = $t->epoch + ($bucket_in_seconds -1);
	my $bucket_upper = Time::Piece->strptime($temptime,"%s")->strftime('%Y%m%d-%H%M%S');
	my $year = $t->strftime('%Y');
	my $month = $t->strftime('%m');
	
	unless(-e "$output_directory1/$year"){
		mkdir "$output_directory1/$year";
	}
	unless(-e "$output_directory1/$year/$month"){
		mkdir "$output_directory1/$year/$month";
	}	
	
	$t = Time::Piece->strptime($temptime+1,"%s");
	
	my $bucket_out = $output_directory1."/".$year."/".$month."/".$prefix.$bucket_lower."_to_".$bucket_upper.".txt";

	if(!keys %$bucket){
		print "$prog: skipping $bucket_out, no entries exist for it.\n";	}
	else{
		open (my $bucket_handle,'>',$bucket_out) or die("Can't open $bucket_out");
    		for my $word ( sort keys %$bucket ) {
			print $bucket_handle $word." ".$bucket->{$word}."\n";
		}
		close($bucket_handle);
	}
}
print "$prog: Bucket writing time in seconds: ".(time()-$bucket_time)."\n";
print "$prog: Total time in seconds: ".(time()-$total_time)."\n";

