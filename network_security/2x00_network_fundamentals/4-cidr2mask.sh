#!/bin/bash
printf "%d.%d.%d.%d" "$((($1>0?(0xFFFFFFFF<<(32-$1))&0xFFFFFFFF:0)>>24&255))" "$((($1>0?(0xFFFFFFFF<<(32-$1))&0xFFFFFFFF:0)>>16&255))" "$((($1>0?(0xFFFFFFFF<<(32-$1))&0xFFFFFFFF:0)>>8&255))" "$((($1>0?(0xFFFFFFFF<<(32-$1))&0xFFFFFFFF:0)&255))"
