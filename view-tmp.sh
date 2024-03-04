#!/bin/bash
tmpfile=$1

cat $tmpfile \
    | tail -n 1 \
    | sed "s|//|\n|g" \
    | awk -F'::' '{printf "%s %.2f %.2f %.0f %.0f %.2f\n", $1, $2, $3, $4, $5, $6}' \
    | column -t -R 2,3,4,5,6 -N DEPLOY,AVG-CPU,AVG-MEM,MAX-CPU,MAX-MEM,PODS
