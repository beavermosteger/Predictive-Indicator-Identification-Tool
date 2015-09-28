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

echo THIS WILL DESTROY EXISTING DATA! IF YOUR NOT SURE, DONT!
echo CTRL-C TO EXIT, ENTER TO CONTINUE
read VAR;

rm ../2word_metrics/master_summaries/*

for i in $(echo ../2word_metrics/metrics_summaries/*/*/* | sort); 
do 
DATEVAR=`echo $i | sed -e's/.*_//' | sed -e's/\.txt//'`; 
echo ""
echo "./build_master_summary.pl -date $DATEVAR";
./build_master_summary.pl -date $DATEVAR;
done
