#!/bin/bash
# Full URI of HTTP requests carrying UNION/SELECT (raw or URL-encoded)
tshark -r "$1" -Y "http.request.uri matches \"(?i)(union|select)\"" -T fields -e http.request.uri 2>/dev/null
