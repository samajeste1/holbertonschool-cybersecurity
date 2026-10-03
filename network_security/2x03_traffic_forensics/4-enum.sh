#!/bin/bash
tshark -r "$1" -Y "http.response.code == 404" 2>/dev/null | wc -l
