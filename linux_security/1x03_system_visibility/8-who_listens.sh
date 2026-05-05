#!/bin/bash
lsof -i TCP:$1 -s TCP:LISTEN -t | xargs -I{} ps -p {} -o comm= 2>/dev/null
