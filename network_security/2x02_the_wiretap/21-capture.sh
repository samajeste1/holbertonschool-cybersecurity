#!/bin/bash
sudo tcpdump -i "$(ip route | awk '/^default/ {print $5; exit}')" -w capture.pcap "(icmp and host $(ip route | awk '/^default/ {print $3; exit}')) or (tcp port 80)"
