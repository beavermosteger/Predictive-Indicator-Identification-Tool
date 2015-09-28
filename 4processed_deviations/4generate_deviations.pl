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
use File::Copy;
use DateTime;
use DateTime::Format::Duration;
use File::Basename;
use Getopt::Long;
use Statistics::Descriptive;
use List::MoreUtils qw(none uniq);
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);
use List::BinarySearch qw( :all );
use Scalar::Util qw(looks_like_number);


binmode(STDOUT, ":utf8");

my $metric_summary_file;
my $outfile;
my $help;
my $verbose;
my $prefix;
my $baseline_file;

GetOptions ("baseline=s" => \$baseline_file,
			"i=s" => \$metric_summary_file,
			"o=s" => \$outfile,
			"h" => \$help,
			"v" => \$verbose);  # flag

		
my $total_time = time();
my $prog = basename($0);
sub usage{
    warn <<"EOF";

DESCRIPTION
  Calculates devations in usage 

EOF

exit 0;
}

usage() and die unless $metric_summary_file;
usage() and die unless $baseline_file;
$outfile = "./4processed_deviations/deviations_".DateTime->now->strftime('%Y%m%d').".txt" unless $outfile;
my $output_directory = dirname($outfile);


sub flush {
   my $h = select($_[0]); my $af=$|; $|=1; $|=$af; select($h);
}


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
	open BASE, "<", $file or die("Error: Can't open $file");
	if (search(\*BASE, sub { $_ cmp $word })) {
		$result = <BASE>;
	}

	if($result){
		$result = (split(/ /,$result,2))[1];
	}
	

	return $result;
}

sub search {
  my ($fh, $cmp) = @_;
  my ($lo, $hi) = (0, -s $fh);

  while (1) {
    my $mid = int(($lo + $hi)/2);
    if ($mid) {
      seek $fh, $mid-1, SEEK_SET;
      my $junk = <$fh>;
    } else { seek $fh , $mid, SEEK_SET; }
    my $start = tell $fh;
    my $rec = <$fh>;
    return unless defined $rec;
    chomp($rec);

    if ($hi == $lo) { 
      seek $fh, $start, SEEK_SET;
      return $rec 
    };
    local $_ = $rec;
    if ($cmp->($rec) < 0) { $lo = $mid+1 }
    else                  { $hi = $mid   }
  }
}


sub three_sigma{
	#returns 0 if value is not an outlier
	#returns 1 if value is a outlier
	my $value = shift;
	my $mean = shift;
	my $std_dev = shift;
	my $result = 0;
	
	$result = 1 if abs($value-$mean) > 3 * $std_dev;
	return $result;
}

sub iqr_outlier{
	#returns 0 if value is not an outlier
	#returns 1 if value is a mild outlier
	#returns 2 if value is an extreme outlier
	my $value = shift;
	my $mean = shift;
	my $std_dev = shift;
	my $result = 0;

	#the z-value for probability .75 is 0.67449
	#the z-value for probability .25 is 0.67449
	my $zscore = 0.67449;
	my $q25 = $mean - ($zscore * $std_dev);
	my $q75 = $mean + ($zscore * $std_dev);
	
	my $inter_quartile_range = $q75-$q25;
	$result = 1 if abs($value-$q75) > 1.5*$inter_quartile_range;
	$result = 2 if abs($value-$q75) > 3.0*$inter_quartile_range;
}


my $line_counter = 0;
my $report_limit = 1000000;
my $loop_time = time();


open(my $OUT,'>:raw:perlio:utf8',$outfile) or die("Can't open $outfile");

open(my $SUMMARY,'<:raw:perlio:utf8',$metric_summary_file) or die("Can't open $metric_summary_file");
my $headers = <$SUMMARY>;
while(<$SUMMARY>){
        if($line_counter > $report_limit){
                print "$prog: Reached $report_limit, duration in seconds:".(time()-$loop_time)."\n";
                $loop_time = time();
                $line_counter = 0;
        }
        $line_counter+=1;


	my $summary_count = 0;
	my ($word,@values) = split(/\s/);
	next if $word =~ /^\s$/;
	grep { $summary_count += $_ } @values;
	print "ERR: $_ SUMMARY ".$summary_count."\n" && next if $summary_count == 0;

	my $baseline_line = grep_file($baseline_file,$word,$output_directory);
	
	next unless $baseline_line;
	chomp($baseline_line);

	my @elements = split(/\s/,$baseline_line);
	my ($word2,$count,$mean,$std_dev);
	if($#elements == 3){
		($word2,$count,$mean,$std_dev) = @elements;
	}
	elsif($#elements == 2){
		#grep isn't giving us the funky symbols, assume its
		#the right "word" and go
		($count,$mean,$std_dev) = @elements;
	}
	else{
		die "ERR: $baseline_line -- ".$#elements."\n";
	}
	next if ( (not looks_like_number($count)) || $count == 0);

	#If outlier then...
	if(three_sigma($summary_count,$mean,$std_dev)){
		print $OUT "$word ".($summary_count - $mean)."\n";
	}
}
close($SUMMARY);

close($OUT);

print "$prog: Total run time in seconds: ".(time()-$total_time)."\n";



