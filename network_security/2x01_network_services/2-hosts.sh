#!/bin/bash
grep -E "^[0-9].*\slocalhost" /etc/hosts | awk '{printf $1; exit}'
