#!/bin/bash
# Protocol Hierarchy Statistics of the capture
tshark -r "$1" -q -z io,phs
