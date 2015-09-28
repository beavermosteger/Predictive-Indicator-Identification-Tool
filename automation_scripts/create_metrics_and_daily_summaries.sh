#!/usr/bin/bash

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

ROOTPATH="/home/beaver/projects/eagerbeaver"
CURPATH=`pwd`


if /usr/sbin/pidof -x $(basename $0) > /dev/null; then
  for p in $(/usr/sbin/pidof -x $(basename $0)); do
    if [ $p -ne $$ ]; then
      echo "Script $0 is already running: exiting"
      exit
    fi
  done
fi


cd $ROOTPATH

for k in $(find $ROOTPATH/1sources/ -type f | sort)
do
	FOUND=0;

	SHORTK=$(echo $k | sed -e 's/.*_//' | sed -e 's/\.txt//');

	for j in $(find $ROOTPATH/2word_metrics/metrics_summaries/ -type f | sort)
	do
		SHORTJ=$(echo $j | sed -e 's/.*_//' | sed -e 's/\.txt//');
		if [[ "x$SHORTK" = "x$SHORTJ" ]]; then
			FOUND=1;
		fi
	done

	if [[ $FOUND == 0 ]]; then
		echo "MISSING $SHORTK"
		echo "./2word_metrics.pl -date $SHORTK"; 
		./2word_metrics.pl -date $SHORTK; 
		echo "./2z_summary.pl -date $SHORTK"; 
		./2z_summary.pl -date $SHORTK; 
	fi
done


cd $CURPATH
