#!/bin/bash
awk '/\blocalhost\b/ && !/^#/ {print $1; exit}' /etc/hosts
