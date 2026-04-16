# Linux Fundamentals & Security Baseline

This project covers Linux fundamentals and security hardening through practical tasks on a legacy server (`srv-legacy-01`). All scripts are developed locally, transferred via `scp`, and executed remotely via `ssh`.

## Workflow

```bash
# Transfer script to remote server
scp <script> student@<IP>:/home/student/

# Execute script remotely
ssh student@<IP> "./<script>"

# Download flag back locally
scp student@<IP>:/home/student/<flag_file> .
```

## Tasks

### Task 0 - Who Dis?
Print the effective username.
- **Script:** `0-its_me.sh`
- **Flag:** `0-flag.txt`

### Task 1 - The Needle in the Haystack
Find a specific file by name across the filesystem.
- **Script:** `1-needle_in_haystack.sh`
- **Flag:** `1-flag.txt`

### Task 2 - Content Mining
Search file content using grep and regex.
- **Script:** `2-content_mining.sh`
- **Flag:** `2-flag.txt`

### Task 3 - The Piping Logic
Use pipes and logical operators to chain commands.
- **Script:** `3-piping_logic.sh`
- **Flag:** `3-flag.txt`

### Task 4 - The SUID Audit
Find all SUID binaries on the system.
- **Script:** `4-suid_audit.sh`
- **Flag:** `4-flag.txt`

### Task 5 - The Immortal File
Work with immutable file attributes using `lsattr`/`chattr`.
- **Script:** `5-immortal_file.sh`
- **Flag:** `5-flag.txt`

### Task 6 - The Collaboration Folder
Create a shared directory with sticky bit permissions.
- **Script:** `6-collab_folder.sh`
- **Flag:** `6-flag.txt`

### Task 7 - The Audit Gateway
Configure ACL permissions on log files.
- **Script:** `7-audit_gateway.sh`
- **Flag:** `7-flag.txt`

### Task 8 - The Log Creation Policy
Set default ACL for a log directory.
- **Script:** `8-log_creation_policy.sh`
- **Flag:** `8-flag.txt`

## Repository

- **GitHub:** holbertonschool-cybersecurity
- **Directory:** linux_security/1x00_linux_fundamentals
