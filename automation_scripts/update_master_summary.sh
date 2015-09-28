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
MASTERSUM="$ROOTPATH/2word_metrics/master_summaries/master_summary"

if /usr/sbin/pidof -x $(basename $0) > /dev/null; then
  for p in $(/usr/sbin/pidof -x $(basename $0)); do
    if [ $p -ne $$ ]; then
      echo "Script $0 is already running: exiting"
      exit
    fi
  done
fi


cd $ROOTPATH;


CURDATE=`head -n2 $MASTERSUM | tail -n1 | awk '{print $2}'`;

for i in $(echo $ROOTPATH/2word_metrics/metrics_summaries/*/*/* | sort); 
do 
	DATEVAR=`echo $i | sed -e's/.*_//' | sed -e's/\.txt//'`; 
	if [[ "$DATEVAR" -gt "$CURDATE" ]]; then
		echo "$ROOTPATH/build_master_summary.pl -date $DATEVAR -i \"$ROOTPATH/2word_metrics/metrics_summaries\" -l \"$ROOTPATH/2word_metrics/errors.txt\" -m \"$MASTERSUM\"";
		$ROOTPATH/automation_scripts/build_master_summary.pl -date $DATEVAR -i "$ROOTPATH/2word_metrics/metrics_summaries" -l "$ROOTPATH/2word_metrics/errors.txt" -m "$MASTERSUM"
	fi
done


cd $CURPATH;


