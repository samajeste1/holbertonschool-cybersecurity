# The Watchtower

Centralized logging for DataFortress: collect system events, keep them off the
compromised host, and alert when an attack shows up in the logs.

| File | Role |
|---|---|
| `0-stats.sh` | Counts lines in `auth.log`, `syslog`, and `kern.log` |
| `1-analyze_ssh.sh` | Ranks source IPs behind SSH `Failed password` attempts |
| `2-detect_sqlmap.sh` | Prints IP, method, and path for requests whose User-Agent contains `sqlmap` |
| `3-setup_loghost.sh` | Enables UDP and TCP syslog reception on port 514 |
| `4-forward_logs.sh` | Forwards all logs to `127.0.0.1` over UDP and sends a test message |
| `5-isolate_auth.sh` | Writes `authpriv.info` events to `/var/log/secure_remote.log` |
| `6-setup_rotation.sh` | Rotates that remote auth log daily, keeps 7 compressed copies |
| `7-json_template.sh` | Defines the `json_fmt` rsyslog template |
| `8-correlate_errors.sh` | Alerts when one IP produces more than five HTTP 4xx responses |
| `9-html_report.sh` | Builds an HTML table of the top five SSH attackers |
| `10-monitor_sudo.sh` | Watches `auth.log` and alerts on sudo failures or sudo commands |

Scripts `3` through `7` edit `/etc` and must be run as root. Log files passed to
the analysis scripts are evidence only: do not execute anything found inside them.
