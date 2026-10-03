#!/bin/bash
n=$1; b=""; for i in {1..8}; do b=$((n % 2))$b; n=$((n / 2)); done; echo "$b"
