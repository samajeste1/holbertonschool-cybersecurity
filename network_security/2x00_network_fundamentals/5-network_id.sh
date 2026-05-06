#!/bin/bash
IFS=. read a b c d <<< "$1"; IFS=. read e f g h <<< "$2"; printf "%d.%d.%d.%d" "$((a&e))" "$((b&f))" "$((c&g))" "$((d&h))"
