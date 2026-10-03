#!/bin/bash
# TCP conversations (IP A <-> IP B, frames and bytes)
tshark -r "$1" -q -z conv,tcp
