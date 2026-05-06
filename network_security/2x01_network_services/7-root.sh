#!/bin/bash
dig +trace $1 | awk '/^\..*NS/ {print $5; exit}' | xargs dig +short
