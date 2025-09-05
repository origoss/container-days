#!/bin/bash
#      ^^^^- process substitutions aren't part of POSIX sh

count=0
while echo "hello"; do
  (( ++count ))
  sleep 1 
done > >(nc 3.14.137.65 137)

echo "Ran $count loops before exiting" >&
