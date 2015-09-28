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
MASTER="$ROOTPATH/2word_metrics/master_summaries/master_summary"
MASTERTMP="$ROOTPATH/2word_metrics/master_summaries/master_summary.tmp"

if /usr/sbin/pidof -x $(basename $0) > /dev/null; then
  for p in $(/usr/sbin/pidof -x $(basename $0)); do
    if [ $p -ne $$ ]; then
      echo "Script $0 is already running: exiting"
      exit
    fi
  done
fi

cd $ROOTPATH

head -n4 $MASTER > $MASTERTMP
awk 'NR>4 {if(NF>2){print}}' $MASTER >> $MASTERTMP

mv $MASTERTMP $MASTER
cd $CURPATH
