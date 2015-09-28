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

LATEST_BASELINE=`find $ROOTPATH/3baselines -name "baseline_*.txt" | sort | tail -n1`;

cp -v "$LATEST_BASELINE" "$LATEST_BASELINE.working"



for k in $(find $ROOTPATH/2word_metrics/metrics_summaries/ -type f | sort)
do
	FOUND=0;

	SHORTK=$(echo $k | sed -e 's/.*_//' | sed -e 's/\.txt//');

	for j in $(find $ROOTPATH/4processed_deviations/ -type f | sort)
	do
		SHORTJ=$(echo $j | sed -e 's/.*_//' | sed -e 's/\.txt//');
		#echo $SHORTK = $SHORTJ?
		if [[ "x$SHORTK" = "x$SHORTJ" ]]; then
			FOUND=1;
		fi
	done

	if [[ $FOUND == 0 ]]; then
		echo "MISSING $SHORTK"
		echo "$ROOTPATH/4generate_deviations.pl -b $LATEST_BASELINE.working -i $k -o \"$ROOTPATH/4processed_deviations/deviations_$SHORTK.txt\"";
		$ROOTPATH/4generate_deviations.pl -b $LATEST_BASELINE.working -i $k -o "$ROOTPATH/4processed_deviations/deviations_$SHORTK.txt";
	fi
done

rm "$LATEST_BASELINE.working"
cd $CURPATH
