#!/bin/bash
IFS=. read a b c d <<< "$1"; IFS=. read e f g h <<< "$2"; printf "%d.%d.%d.%d" "$(((a&e)|(255&~e)))" "$(((b&f)|(255&~f)))" "$(((c&g)|(255&~g)))" "$(((d&h)|(255&~h)))"
