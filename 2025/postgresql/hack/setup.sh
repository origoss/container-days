#!/usr/bin/evnv bash

set -e

sudo ip link add dummy0 type dummy
sudo ip addr add 3.14.137.65/28 dev dummy0
