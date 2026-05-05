#!/bin/bash
awk '/PPid/ {print $2}' /proc/$1/status
