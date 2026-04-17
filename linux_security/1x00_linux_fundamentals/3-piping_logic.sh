#!/bin/bash
find /home -type f 2>/dev/null | xargs ls -la 2>/dev/null | awk '{print $1, $3, $4, $9}' | grep "larry"
