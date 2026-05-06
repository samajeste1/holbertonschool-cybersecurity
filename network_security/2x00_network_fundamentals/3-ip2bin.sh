#!/bin/bash
echo "$1" | awk -F. '{for(i=1;i<=4;i++){b="";n=$i;for(j=7;j>=0;j--){b=b int(n/2^j)%2};printf b (i<4?".":" ")}printf "\n"}'
