#!/bin/bash
ip route | awk '/^default/ { print $3; exit }'
