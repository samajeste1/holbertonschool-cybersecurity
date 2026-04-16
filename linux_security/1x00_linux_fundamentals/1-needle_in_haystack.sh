#!/bin/bash
find / -type f -name "*.txt" -size 33c 2>/dev/null | grep -v proc | grep -v sys
