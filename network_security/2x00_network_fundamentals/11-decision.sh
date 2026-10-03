#!/bin/bash
ip route get "$1" 2>/dev/null | grep -qw via && echo REMOTE || echo LOCAL
