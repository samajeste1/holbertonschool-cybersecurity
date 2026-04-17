#!/bin/bash
find / -not -path "/proc/*" -not -path "/sys/*" 2>/dev/null | xargs lsattr 2>/dev/null | grep -- "-i-"
