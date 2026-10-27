#!/bin/bash
scp skeleton.conf 2-panic.sh engineer@acme-gw01:/tmp/ && ssh engineer@acme-gw01 "bash /tmp/2-panic.sh && nft -f /tmp/skeleton.conf && nft list ruleset"
