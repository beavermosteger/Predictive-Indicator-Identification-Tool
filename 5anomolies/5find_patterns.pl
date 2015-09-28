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

my @dates;
my $time_period=7;
my $acceptable_deviation;
my $keyword;
my $baseline_file;
my $input_file;
my $input_directory;
my $output_file;
my $output_directory;
my $verbose;
my $help;
my $out_part_file;
my $out_comp_file;
my $partial_match_threshold;
my $file_partial_prefix;



GetOptions ("date=s" => \@dates,
			"period=s" => \$time_period,
			"deviation=i" => \$acceptable_deviation,
			"key=s"   => \$keyword,      # string
			"i=s" => \$input_file,
			"o=s" => \$output_file,
			"h" => \$help,
			"v" => \$verbose);  # flag


			
my $prog = basename($0);
sub usage{
    warn <<"EOF";

DESCRIPTION
	Answers the 'if' and 'how' questions.

EOF

exit 0;
}

warn "\nError: no dates defined!\n" and usage() unless @dates;
warn "\nError: no key defined!\n" and usage() unless $keyword;
warn "\nError: no  defined!\n" and usage() unless @dates;
warn "\nError: no dates defined!\n" and usage() unless @dates;
			
if($help){
	usage();
}


$input_directory="./4processed_deviations" unless $input_directory;
$output_directory = "./5anomolies" unless $output_directory;
$file_partial_prefix = "deviations_" unless $file_partial_prefix;

#partial matches
$out_part_file = "pattern_partial_".$keyword."_".DateTime->now->strftime('%Y%m%d-%H%M%S').".txt" unless $out_part_file;
#complete matches
$out_comp_file = "pattern_complete_".$keyword."_".DateTime->now->strftime('%Y%m%d-%H%M%S').".txt" unless $out_comp_file;

#if not defined then define the threshold
$partial_match_threshold = 2 unless $partial_match_threshold;



my @AoH;

open (my $handle1,'>>',$output_directory."/".$out_part_file) or die("Can't open $out_part_file");
open (my $handle2,'>>',$output_directory."/".$out_comp_file) or die("Can't open $out_comp_file");

print $handle1 "#KEYWORD: ".$keyword."\n";
print $handle2 "#KEYWORD: ".$keyword."\n";

for my $date (@dates){
	my $dt = DateTime->from_epoch( epoch => (Time::Piece->strptime(($date."-00:00:00"),"%Y%m%d-%H:%M:%S")->epoch));
	
	my $header = "#Range: ".$dt->strftime('%Y%m%d-%H%M%S');
	$dt->subtract( days => $time_period );
	$header = $header." to ".$dt->strftime('%Y%m%d-%H%M%S')."\n";
	print $handle1 $header;
	print $handle2 $header;
}
print $handle1 "#LEGEND: WORD DEVIATION ORIGIN_DATE BUCKET_DATE_STAMP DELTA_WITH_ORIGIN SOURCE FULL_BUCKET_NAME ORIGIN_WINDOW\n";
print $handle2 "#LEGEND: WORD DEVIATION ORIGIN_DATE BUCKET_DATE_STAMP DELTA_WITH_ORIGIN SOURCE FULL_BUCKET_NAME ORIGIN_WINDOW\n";

close($handle1);
close($handle2);




my $date_range_counter = 0;
for my $date (@dates){
	print "START LOOP\n" if $verbose;
	my @new_dates = ();
	my $dt = DateTime->from_epoch( epoch => (Time::Piece->strptime(($date."-00:00:00"),"%Y%m%d-%H:%M:%S")->epoch));
	push(@new_dates,$dt->strftime('%Y%m%d'));
	for my $i (keys [1..($time_period-1)]){
		$dt->subtract( days => 1 );
		my $date_as_str = $dt->strftime('%Y%m%d');
		push(@new_dates,$date_as_str) if none { /$date_as_str/ } @new_dates;
	}
		
	$date_range_counter++;

	my @target_files=();
	for my $date (@new_dates){

		my $basefilename = $file_partial_prefix.$date;
		print "\tBase: $basefilename\n" if $verbose;

		opendir(DIR, $input_directory) or die $!;

		while (my $file = readdir(DIR)) {
			# We only want files
			next unless (-f "$input_directory/$file");
			print "$file =~ /.*".$basefilename.".*/ ?\n" if $verbose;
			# Use a regular expression to find files ending in .txt
			next unless ($file =~ /.*$basefilename.*/);
			print "\t\tFound file: $file\n" if $verbose;
			push(@target_files,$file);
		}
		closedir(DIR);
	} 

	my %inputs = ();

	my $total_files = $#target_files;

	for my $file (@target_files){
		my $path_to_file = $input_directory."/".$file;
		print "Path to target file: ".$path_to_file."\n" if $verbose;
		
		open (my $target_handle,'<',$path_to_file) or die("Can't open ".$path_to_file."\n");
		
		while (<$target_handle>) {
			chomp;
			my $line = $_;
			my ($word,$deviation) = split(/ /,$line);
			my $stamp = $file;
			#$stamp =~ s/$file_partial_prefix//;
			$stamp =~ s/\.txt//;
			$inputs{$stamp}{$word} = $deviation;
		}
	}

	if ($verbose) {
		for my $k1 ( sort keys %inputs ) {
			print "$k1\n";
		 
			for my $k2 ( sort keys %{$inputs{ $k1 }} ) {
				print "\t$k2 => ".$inputs{ $k1 }{ $k2 }."\n";
			}
		}
	}

	print "Total files: $total_files\n" if $verbose;
	my %matches = ();

	for my $stamp (sort keys %inputs) {
		for my $word ( sort keys %{$inputs{$stamp}} ) {
			if(exists $matches{$word}{word}){
				$matches{$word}{count} = $matches{$word}{count} + 1;
				$matches{$word}{$stamp} = $inputs{$stamp}{$word};
			}
			else{
				$matches{$word}{count} = 1;
				$matches{$word}{$stamp} = $inputs{$stamp}{$word};
				$matches{$word}{word} = $word;
				
				#very inefficient, yes I know... bite me
				$matches{'origin'} = {date => $date};
			}
		}
	}



	for my $word ( sort keys %matches ) {
		my $stat = Statistics::Descriptive::Sparse->new();
		if($word eq 'origin'){ next; }
		my $word_count = $matches{$word}{count};
		if($word_count < 2){ next; }
		my @out_dates = ();
		for my $datestamp ( sort keys %{$matches{ $word }} ) {
			if ($datestamp eq "word" or $datestamp eq "count") { next; }
			$stat->add_data($matches{$word}{$datestamp});
			push(@out_dates,$datestamp);
		}
		
		#Make sure all our data is deviating in the same direction
		if($stat->max() < 0 or $stat->min() > 0){
			#do stuff
			print $word." ".$word_count." ".join(",",@out_dates)."\n-------------\n" if $verbose;
			
		}
		else{
			#kill the key for 'word'
			#print "Bad word: $word\n" if $verbose;
			delete $matches{$word};
		
		}
	}
	print "Object after stripping:\n".Dumper(%matches)."\n" if $verbose;

	push(@AoH,\%matches);
	
} #end 


my $aoh_size = ($#AoH + 1);

print "AoH Size: ".$aoh_size."\n" if $verbose;

my @complete;
my @partial;


my @word_list = ();


my $line_counter = 0;
my $report_limit = 1000000;
my $loop_time = time();
for my $hash (@AoH){
	for my $word ( sort keys %{$hash} ) {
		if($word eq 'origin'){ next; }
		print "Checking for $word...\n" if $verbose;

		if($line_counter > $report_limit){
			print "$prog: Reached $report_limit, duration in seconds:".(time()-$loop_time)."\n";
			$loop_time = time();
			$line_counter = 0;
		}
		$line_counter+=1;

		push(@word_list,$word) if none { $_ eq $word } @word_list;
	}
}


print "Wordlist:\n" if $verbose;
for my $word (@word_list){ 
	print "\t$word\n" if $verbose;
}



#figure out whats partial vs complete and save it off
for my $word (@word_list){ 
	my $word_counter = 0;
	for my $hash (@AoH){
		
		if(exists($hash->{$word})){
			$word_counter++;
		}
	}
	if($date_range_counter == $word_counter){
		print "$word found as complete... $date_range_counter == $word_counter\n";
		open (my $handle,'>>',$output_directory."/".$out_comp_file) or die("Can't open $out_comp_file");
		for my $hash (@AoH){	
			if(exists($hash->{$word})){
				for my $stamp ( sort keys %{$hash->{ $word }} ) {
					if($stamp eq 'word' or $stamp eq 'count'){ next; }
					my $source = (split('_',$stamp))[0];
					my ($bucket_start,$bucket_end);
					
					my $final_stamp = $stamp;
					$final_stamp =~ s/.*deviations_//;
					print "FINAL_STAMP: $final_stamp\n" if $verbose;
					
					($bucket_start,$bucket_end) = split('_to_',$final_stamp);
					my $origin = $hash->{origin}{date};
					print "Start: $bucket_start\n" if $verbose;
					print "End: $bucket_end\n" if $verbose;
					print "Origin: $origin\n" if $verbose;
					my $dt_start = DateTime->from_epoch( epoch => (Time::Piece->strptime($bucket_start,"%Y%m%d-%H%M%S")->epoch));
					my $dt_end = DateTime->from_epoch( epoch => (Time::Piece->strptime($bucket_end,'%Y%m%d-%H%M%S')->epoch));					
					
					#get origin and compare
					my $dt_origin = DateTime->from_epoch( epoch => (Time::Piece->strptime($origin."-000000","%Y%m%d-%H%M%S")->epoch));
					my $duration = $dt_end - $dt_origin;
					my $dt_origin_start = $dt_origin;
					$dt_origin_start->subtract( days => $time_period );
					
					my $format = DateTime::Format::Duration->new(
						pattern => '%yy%mm%dd%Hh%Mm%Ss'
					);
					my %normalized_duration = $format->normalise($duration);
					#print Dumper($normalized_duration)."\n";
					my $delta_with_origin = $normalized_duration{years}."Y".
										    $normalized_duration{months}."M".
										    $normalized_duration{days}."D".
										    $normalized_duration{hours}."h".
										    $normalized_duration{minutes}."m".
										    $normalized_duration{seconds}."s".
										    $normalized_duration{nanoseconds}."n";
					print "Duration: ".$delta_with_origin."\n" if $verbose;
					
					$dt_origin_start->strftime('%Y%m%d')."_to_".$dt_origin->strftime('%Y%m%d');
					
					#LEGEND: WORD DEVIATION ORIGIN_DATE BUCKET_DATE_STAMP DELTA_WITH_ORIGIN SOURCE FULL_BUCKET_NAME ORIGIN_WINDOW
					print $handle $word." ".$hash->{$word}{$stamp}." ".$hash->{origin}{date}." ".$final_stamp." ".$delta_with_origin." ".$source." ".$stamp." ".$dt_origin_start->strftime('%Y%m%d')."_to_".$dt_origin->strftime('%Y%m%d')."\n";
				}
			}
		}
		
		close($handle);	
	}
	elsif($partial_match_threshold <= $word_counter){
		print "$word found as partial... $partial_match_threshold == $word_counter\n";
		open (my $handle,'>>',$output_directory."/".$out_part_file) or die("Can't open $out_part_file");
		for my $hash (@AoH){	
			if(exists($hash->{$word})){
				for my $stamp ( sort keys %{$hash->{ $word }} ) {
					if($stamp eq 'word' or $stamp eq 'count'){ next; }
					my $source = (split('_',$stamp))[0];
					my ($bucket_start,$bucket_end);
					
					my $final_stamp = $stamp;
					$final_stamp =~ s/.*deviations_//;
					print "FINAL_STAMP: $final_stamp\n" if $verbose;
					
					($bucket_start,$bucket_end) = split('_to_',$final_stamp);
					my $origin = $hash->{origin}{date};
					print "Start: $bucket_start\n" if $verbose;
					print "End: $bucket_end\n" if $verbose;
					print "Origin: $origin\n" if $verbose;
					my $dt_start = DateTime->from_epoch( epoch => (Time::Piece->strptime($bucket_start,"%Y%m%d-%H%M%S")->epoch));
					my $dt_end = DateTime->from_epoch( epoch => (Time::Piece->strptime($bucket_end,'%Y%m%d-%H%M%S')->epoch));
					
					
					#get origin and compare
					my $dt_origin = DateTime->from_epoch( epoch => (Time::Piece->strptime($origin."-000000","%Y%m%d-%H%M%S")->epoch));
					my $duration = $dt_end - $dt_origin;
					my $dt_origin_start = $dt_origin;
					$dt_origin_start->subtract( days => $time_period );
					
					my $format = DateTime::Format::Duration->new(
						pattern => '%yy%mm%dd%Hh%Mm%Ss'
					);
					my %normalized_duration = $format->normalise($duration);
					#print Dumper($normalized_duration)."\n";
					my $delta_with_origin = $normalized_duration{years}."Y".
										    $normalized_duration{months}."M".
										    $normalized_duration{days}."D".
										    $normalized_duration{hours}."h".
										    $normalized_duration{minutes}."m".
										    $normalized_duration{seconds}."s".
										    $normalized_duration{nanoseconds}."n";
					print "Duration: ".$delta_with_origin."\n" if $verbose;
					
					$dt_origin_start->strftime('%Y%m%d')."_to_".$dt_origin->strftime('%Y%m%d');
					
					#LEGEND: WORD DEVIATION ORIGIN_DATE BUCKET_DATE_STAMP DELTA_WITH_ORIGIN SOURCE FULL_BUCKET_NAME ORIGIN_WINDOW
					print $handle $word." ".$hash->{$word}{$stamp}." ".$hash->{origin}{date}." ".$final_stamp." ".$delta_with_origin." ".$source." ".$stamp." ".$dt_origin_start->strftime('%Y%m%d')."_to_".$dt_origin->strftime('%Y%m%d')."\n";
				}
			}
		}

		close($handle);	
	}
	else{
		print "$word not matched... $word_counter\n";
	}
	
}
