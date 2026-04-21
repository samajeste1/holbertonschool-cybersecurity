#!/bin/bash
find $1 -maxdepth 1 -name "*.log" | xargs -I {} mv {} {}.old
