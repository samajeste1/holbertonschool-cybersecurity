#!/bin/bash
printf '%08d' "$(echo "obase=2;$1" | bc)"
