#!/bin/bash
traceroute -n $1 | tail -1 | awk '{print $1}'
