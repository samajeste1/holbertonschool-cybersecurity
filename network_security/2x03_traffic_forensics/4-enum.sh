#!/bin/bash
# Count of HTTP 404 responses (directory brute-forcing)
tshark -r "$1" -Y "http.response.code == 404" 2>/dev/null | wc -l
