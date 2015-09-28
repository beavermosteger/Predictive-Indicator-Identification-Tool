#!/usr/bin/perl

#Description
#This script collects statistically relevant data from a twitter feed
#The OAUTH and CONSUMER variables need to be changed to use your credentials for twitter.

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



use AnyEvent::Twitter::Stream;
use Time::Piece;
use Scalar::Util 'blessed';
use Data::Dumper;  # print Dumper($foo);
use DateTime;
use Getopt::Long;
use utf8;
use open ':encoding(utf8)';

my $OAUTH_TOKEN = '12345';
my $OAUTH_SECRET = '123456';
my $CONSUMER_KEY = '123';
my $CONSUMER_SECRET = '1234567';

my $INTERNAL_TWITTER_RATE_LIMITER = 50;
my $TWITTER_QUERY_SIZE = 100;

my $tweetid;
my $stockdate;
my $stocksymbols;
my $skipTwitter;
my $skipStock;
my $output_directory;


GetOptions ("tweetid=s"   => \$tweetid,      # string
			"stockdate=s" => \$stockdate,
			"stocksymbols=s" => \$stocksymbols,
			"outputdir=s" => \$output_directory,
			"skipTwitter"  => \$skipTwitter,  # flag
			"skipStock"  => \$skipStock);  # flag

			
binmode(STDOUT, ":utf8");



$output_directory = "./1sources" unless $output_directory;

$twitter_collection = "twitter_stream_".DateTime->now->strftime('%Y%m%d').".txt";
open ($twitter_handle,'>>',$output_directory."/".$twitter_collection) or die("Cant open $twitter_collection");

			
my $del_counter = 0;

while(1){
	print "Reset AnyEvent\n";
	my $done = AnyEvent->condvar;
	my $listener = AnyEvent::Twitter::Stream->new(
		consumer_key    => $CONSUMER_KEY,
		consumer_secret => $CONSUMER_SECRET,
		token           => $OAUTH_TOKEN,
		token_secret    => $OAUTH_SECRET,
		method          => "sample",

		on_tweet => sub {
			my $tweet = shift;
			#print Dumper($tweet)."\n";
			if($twitter_collection ne ("twitter_stream_".DateTime->now->strftime('%Y%m%d').".txt")){
				close ($twitter_handle) or die ("Unable to close ".$twitter_collection);
				$twitter_collection = "twitter_stream_".DateTime->now->strftime('%Y%m%d').".txt";
				open ($twitter_handle,'>>',$output_directory."/".$twitter_collection) or die("Cant open ".$twitter_collection);
			}

			my $t = Time::Piece->strptime($tweet->{created_at},"%a %b %d %H:%M:%S %z %Y")->strftime("%Y%m%d-%H:%M:%S");
			#warn "$t $tweet->{user}{screen_name}: $tweet->{text}\n";
			if ($t eq "19700001-00:00:00") { print $twitter_handle Dumper($tweet); }
			else{ 
				print $twitter_handle $t." ".$tweet->{id}." ".$tweet->{user}{screen_name}.": ".$tweet->{text}."KPBLOCK\n";
			}
			#warn "$tweet->{user}{screen_name}: $tweet->{text}\n";
		},
		on_connect => sub {
			warn DateTime->now->strftime('%Y%m%d %H:%M:%S').": connected\n";
		},
		on_error => sub {
			my $issue = shift;
			warn DateTime->now->strftime('%Y%m%d %H:%M:%S').": error: ".Dumper($issue)."\n";
			$done->send; 
		},
		on_eof => sub {
			my $issue = shift;
			warn DateTime->now->strftime('%Y%m%d %H:%M:%S').": eof: ".Dumper($issue)."\n";
		},
		on_keepalive => sub {
			warn DateTime->now->strftime('%Y%m%d %H:%M:%S').": ping\n";
		},
		on_delete => sub {
			$del_counter++;
			if($del_counter > 500){
				$del_counter=0;
				warn DateTime->now->strftime('%Y%m%d %H:%M:%S').": 500 deletes\n";
			}
		},
		timeout => 60,
	);

	eval{
		$done->recv;
	};
	#sleep 30;
}

close ($twitter_handle) or die ("Unable to close $twitter_collection");


