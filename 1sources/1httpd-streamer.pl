#!/usr/bin/perl

# Copyright (C) 2019 Brian Spargur

# Copyright (C) 2019 Kevin Spargur




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









# yum install perl-Time-Piece perl-Data-Dumper perl-DateTime

use Time::Piece;
use Scalar::Util 'blessed';
use Data::Dumper;  # print Dumper($foo);
use DateTime;
use Getopt::Long;
use utf8;
use open ':encoding(utf8)';
use File::Path qw( make_path );

my $tweetid;
my $stockdate;
my $stocksymbols;
my $skipTwitter;
my $skipStock;
my $output_directory;


GetOptions ("outputdir=s" => \$output_directory,
            "logfile=s" => \$logfile,
            "seperator=s" => \$output_seperator,
            "outprefix=s" => \$output_prefix);  # flag


binmode(STDOUT, ":utf8");



$output_directory = "./1sources" unless $output_directory;
$output_prefix = "twitter_stream" unless $output_prefix;
$output_seperator = "|" unless $output_seperator;

if (! -d $dir) {
    make_path $output_directory;
}

if ($logfile =~ /.gz$/) {
    open(IN, "gunzip -c $logfile |") || die "canâ€™t open pipe to $file, gunzip missing?";
}
else {
    open(IN, $logfile) || die "canâ€™t open $file";
}



while (<IN>){
    $_ = /^(?<host>[^ ]+)\s(?<identd>[^ ]+)\s(?<userid>[^ ]+)\s\[(?<timestamp>[^\]]+)\]\s"(?<request>[^"]+)"\s(?<status>[^ ]+)\s(?<size>[^ ]+)\s"(?<referrer>[^"]+)"\s"(?<useragent>[^"]+).*$/x;
    #   17/May/2015:10:05:12 +0000
    my $t = Time::Piece->strptime($+{timestamp}, "%d/%B/%Y:%H:%M:%S %z");
    my $time_t = $t->epoch;

    #print "Host: $+{host}, Identd: $+{identd}, Userid: $+{userid}, Timestamp: $+{timestamp}, Request: $+{request}, Status: $+{status}, Size: $+{size}, Referrer: $+{referrer}, Useragent: $+{useragent}\n";


    $collection = $output_prefix."_".$t->strftime('%Y%m%d').".txt";
    open ($twitter_handle,'>>',$output_directory."/".$collection) or die("Cant open $collection");

    #print $twitter_handle $t." ".$tweet->{id}." ".$tweet->{user}{screen_name}.": ".$tweet->{text}."KPBLOCK\n";
    #print $twitter_handle $t." ".$+{host}." ".$+{request}." ".$+{status}."\n";
    #print $time_t.$output_seperator.$+{host}.$output_seperator.$+{request}.$output_seperator.$+{status}."\n";
    print $twitter_handle $time_t.$output_seperator.$+{host}.$output_seperator.$+{request}.$output_seperator.$+{status}."\n";

    close($twitter_handle) or die ("Unable to close $collection");
}



close(IN) or die ("Unable to close $logfile");

exit 0;
