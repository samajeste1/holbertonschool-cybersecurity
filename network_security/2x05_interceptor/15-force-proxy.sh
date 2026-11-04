#!/bin/bash
# Local output is the proxy itself. It must still open HTTP and HTTPS.
nft add rule inet filter output tcp dport 80 accept
nft add rule inet filter output tcp dport 443 accept

# VPN clients are forwarded out of wg0. Each insert lands at the head,
# so the accept (proxy exception) is evaluated before the drops, and
# both sit ahead of "iifname wg0 accept" from the perimeter policy.
nft insert rule inet filter forward ip saddr 10.200.0.0/24 oifname != "wg0" tcp dport 443 drop
nft insert rule inet filter forward ip saddr 10.200.0.0/24 oifname != "wg0" tcp dport 80 drop
nft insert rule inet filter forward ip saddr 10.200.0.0/24 ip daddr 10.200.0.1 tcp dport { 80, 443 } accept
