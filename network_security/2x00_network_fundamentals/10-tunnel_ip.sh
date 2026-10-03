#!/bin/bash
ip addr show tun0 2>/dev/null | awk '/inet / { split($2, a, "/"); print a[1]; exit }'
