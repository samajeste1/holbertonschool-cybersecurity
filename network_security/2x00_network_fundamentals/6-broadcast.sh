#!/bin/bash
IFS=. read -r a b c d <<< "$1"; IFS=. read -r e f g h <<< "$2"; echo "$(((a & e) | (255 ^ e))).$(((b & f) | (255 ^ f))).$(((c & g) | (255 ^ g))).$(((d & h) | (255 ^ h)))"
