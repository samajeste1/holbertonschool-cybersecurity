#!/bin/bash
IFS=. read a b c d <<< "$1"; IFS=. read e f g h <<< "$2"; echo "$((a&e)).$((b&f)).$((c&g)).$((d&h))"
