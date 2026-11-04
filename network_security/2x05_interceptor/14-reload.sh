#!/bin/bash
if ! squid -k parse; then
    exit 1
fi
squid -k reconfigure
