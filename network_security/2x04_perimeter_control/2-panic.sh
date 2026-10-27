#!/bin/bash
nft flush ruleset && (sleep 300 && nft flush ruleset) &
