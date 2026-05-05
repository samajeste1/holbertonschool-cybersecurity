#!/bin/bash
ss -tlnH4 | awk '{print $4}' | awk -F: '{print $NF}' | sort -n
