#!/bin/bash
grep -E "^[0-9].*\slocalhost" /etc/hosts | awk '{print $1}' | head -1
