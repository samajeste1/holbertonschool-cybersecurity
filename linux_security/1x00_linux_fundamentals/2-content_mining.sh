#!/bin/bash
grep -r "password" /etc/ 2>/dev/null | grep -v "#" | grep -v "Binary"
