#!/bin/bash
IFS=. read -r o1 o2 o3 o4 <<< "$1"; r=""; for o in "$o1" "$o2" "$o3" "$o4"; do b=""; for i in {1..8}; do b=$((o % 2))$b; o=$((o / 2)); done; r="$r.$b"; done; echo "${r#.}"
