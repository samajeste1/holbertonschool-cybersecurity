#!/bin/bash
lsof -iTCP:$1 -sTCP:LISTEN -t | xargs -I{} ps -p {} -o comm= 2>/dev/null
