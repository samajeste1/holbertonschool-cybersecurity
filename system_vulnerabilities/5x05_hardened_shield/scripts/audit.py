#!/usr/bin/env python3
"""NovaTech security audit. Scores kernel, filesystem, identity, services, and container controls."""

import argparse
import os
import pwd
import re
import shutil
import subprocess
from pathlib import Path


def read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def running(name):
    if not shutil.which("pgrep"):
        return False
    return subprocess.call(["pgrep", "-x", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0


def port_open(port):
    try:
        proc = subprocess.run(
            ["ss", "-ltn"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return False
    return re.search(rf":{port}\b", proc.stdout) is not None


def web_ok():
    if not shutil.which("curl"):
        return False
    return subprocess.call(
        ["curl", "-fsS", "http://127.0.0.1/"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ) == 0


def root_locked():
    shadow = read_text("/etc/shadow")
    for line in shadow.splitlines():
        if line.startswith("root:"):
            field = line.split(":", 2)[1]
            return field.startswith("!") or field.startswith("*")
    return False


def non_root_user():
    try:
        user = pwd.getpwnam("appuser")
    except KeyError:
        return False
    return user.pw_uid != 0


def in_container():
    if Path("/.dockerenv").exists():
        return True
    return "docker" in read_text("/proc/1/cgroup") or "containerd" in read_text("/proc/1/cgroup")


def no_new_privs():
    status = read_text("/proc/1/status")
    return "NoNewPrivs:\t1" in status or "NoNewPrivs:	1" in status


def collect():
    sysctl = read_text("/etc/sysctl.d/99-hardening.conf")
    fstab = read_text("/etc/fstab")
    pwq = read_text("/etc/security/pwquality.conf")
    faillock = read_text("/etc/security/faillock.conf")
    login_defs = read_text("/etc/login.defs")
    ssh_drop = read_text("/etc/ssh/sshd_config.d/99-hardened.conf")
    ssh_main = read_text("/etc/ssh/sshd_config")
    ssh = ssh_drop + "\n" + ssh_main
    banner = read_text("/etc/issue.net")

    categories = [
        ("Kernel hardening", [
            ("net.ipv4.ip_forward = 0", "net.ipv4.ip_forward = 0" in sysctl),
            ("reverse path filter enabled", "net.ipv4.conf.all.rp_filter = 1" in sysctl),
            ("SYN cookies enabled", "net.ipv4.tcp_syncookies = 1" in sysctl),
            ("ICMP redirects disabled", "net.ipv4.conf.all.accept_redirects = 0" in sysctl),
            ("source routing disabled", "net.ipv4.conf.all.accept_source_route = 0" in sysctl),
        ]),
        ("Filesystem security", [
            ("/tmp noexec in fstab", "noexec" in fstab and "/tmp" in fstab),
            ("/tmp nosuid in fstab", "nosuid" in fstab and "/tmp" in fstab),
            ("/tmp nodev in fstab", "nodev" in fstab and "/tmp" in fstab),
            ("/dev/shm noexec in fstab", "/dev/shm" in fstab and "noexec" in fstab),
        ]),
        ("Identity security", [
            ("password minlen 12", re.search(r"^minlen\s*=\s*12\s*$", pwq, re.M) is not None),
            ("faillock deny 5", re.search(r"^deny\s*=\s*5\s*$", faillock, re.M) is not None),
            ("PermitRootLogin no", re.search(r"^PermitRootLogin\s+no\s*$", ssh, re.M) is not None),
            ("PasswordAuthentication no", re.search(r"^PasswordAuthentication\s+no\s*$", ssh, re.M) is not None),
            ("PASS_MAX_DAYS 90", re.search(r"^PASS_MAX_DAYS\s+90\s*$", login_defs, re.M) is not None),
            ("root account locked", root_locked()),
        ]),
        ("Service security", [
            ("nginx running", running("nginx")),
            ("sshd running", running("sshd")),
            ("port 80 and 22 listening", port_open(80) and port_open(22)),
            ("legal banner present", "AUTHORIZED ACCESS ONLY" in banner),
            ("web health check", web_ok()),
        ]),
        ("Container security", [
            ("running inside a container", in_container()),
            ("non-root application user appuser", non_root_user()),
            ("no-new-privileges on pid 1", no_new_privs()),
            ("host keys present", Path("/etc/ssh/ssh_host_ed25519_key").exists()),
        ]),
    ]
    return categories


def render(categories):
    lines = ["# Security Audit Result", ""]
    total = 0
    passed = 0
    for name, checks in categories:
        good = sum(1 for _, ok in checks if ok)
        total += len(checks)
        passed += good
        lines.append(f"## {name}")
        lines.append("")
        for label, ok in checks:
            state = "PASS" if ok else "FAIL"
            lines.append(f"- [{state}] {label}")
        lines.append("")
        lines.append(f"Score: {good}/{len(checks)}")
        lines.append("")
    percent = 0 if total == 0 else round((passed / total) * 100)
    status = "PASS" if percent >= 80 else "FAIL"
    lines.extend([
        "## Overall",
        "",
        f"Passed checks: {passed}/{total}",
        f"Overall percentage: {percent}%",
        f"Pass/fail status: {status}",
        "",
    ])
    return "\n".join(lines), status


def write_report(path, text):
    target = Path(path)
    try:
        target.write_text(text, encoding="utf-8")
        return target
    except OSError:
        fallback = Path("/tmp/audit_result.md")
        fallback.write_text(text, encoding="utf-8")
        return fallback


def main():
    parser = argparse.ArgumentParser(description="Audit the hardened shield image")
    default_report = str(Path(__file__).resolve().parent / "audit_result.md")
    parser.add_argument("-o", "--output", default=default_report)
    args = parser.parse_args()
    text, status = render(collect())
    written = write_report(args.output, text)
    print(text)
    print(f"Wrote {written}")
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
