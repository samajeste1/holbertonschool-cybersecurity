#!/bin/bash

while true; do
    tail -f /var/log/auth.log | while IFS= read -r line; do
        case "$line" in
            *sudo*)
                case "$line" in
                    *COMMAND*|*authentication\ failure*|*incorrect\ password*)
                        echo "ALERT: Sudo violation detected!"
                        ;;
                esac
                ;;
        esac
    done
    sleep 1
done
