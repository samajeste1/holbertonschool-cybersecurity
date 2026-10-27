# LogiCorp Gateway - Implementation Plan

**Prepared by:** IronShield Consulting
**Date:** 2026-10-27
**Classification:** Confidential

---

## 1. Implementation Sequence

The order of operations is critical. Incorrect sequencing will result in lockout or service disruption.

### Guiding Principles
1. **Never apply firewall rules without a panic button (rollback timer)**
2. **Verify connectivity after each step before proceeding**
3. **Harden services before restricting network access**
4. **VPN must work before SSH is restricted to VPN-only**

---

## 2. Phase 1: System Hardening (clean.sh)

**Risk Level:** LOW - No network changes
**Rollback:** Service restart

### Steps:
1. Update package lists
2. Disable unnecessary services
3. Harden SSH configuration:
   - Disable root login (`PermitRootLogin no`)
   - Disable password authentication (`PasswordAuthentication no`)
   - Ensure public key authentication is enabled
4. Restart SSH service
5. **VERIFY:** SSH reconnection with key-based auth

### Rollback Plan:
If SSH is misconfigured, use console access (Multipass shell) to restore `/etc/ssh/sshd_config` from backup.

---

## 3. Phase 2: VPN Deployment (vpn_setup.sh)

**Risk Level:** LOW - Additive change, no existing services affected
**Rollback:** `wg-quick down wg0`

### Steps:
1. Install wireguard and wireguard-tools (if not present)
2. Generate server keypair
3. Deploy wg0.conf to /etc/wireguard/
4. Set permissions (chmod 600)
5. Start Wireguard: `wg-quick up wg0`
6. Enable at boot: `systemctl enable wg-quick@wg0`
7. **VERIFY:** `wg show wg0` shows interface is up

### Client Side:
1. Generate client keypair
2. Create client.conf with server's public key and endpoint
3. Start client: `wg-quick up client`
4. **VERIFY:** `ping 10.200.0.1` succeeds through VPN

### Rollback Plan:
```bash
wg-quick down wg0
systemctl disable wg-quick@wg0
```

---

## 4. Phase 3: Firewall Deployment (firewall.sh)

**Risk Level:** CRITICAL - Can cause immediate lockout
**Rollback:** Panic button (automatic reset in 5 minutes)

### Pre-Flight Checklist:
- [ ] VPN tunnel is established and verified
- [ ] SSH works through VPN (10.200.0.1)
- [ ] Panic button script is ready
- [ ] Second terminal/console access is available

### Steps:
1. **RUN PANIC BUTTON FIRST:**
   ```bash
   nft flush ruleset && (sleep 300 && nft flush ruleset) &
   ```
   This schedules an automatic firewall reset in 5 minutes.

2. Apply firewall configuration:
   ```bash
   nft -f /etc/nftables.conf
   ```

3. **IMMEDIATE VERIFICATION (within 5 minutes):**
   - [ ] SSH via VPN still works
   - [ ] Ping to gateway works
   - [ ] FTP via VPN works
   - [ ] Internet connectivity from gateway works

4. If verification passes:
   - Cancel panic timer: `kill %1` (or kill the background sleep process)
   - Save rules for persistence

5. If verification fails:
   - Wait 5 minutes for automatic reset
   - Diagnose and fix the configuration
   - Repeat from step 1

### Rollback Plan:
Automatic - the panic button resets all rules in 5 minutes.

---

## 5. Phase 4: SSH Restriction

**Risk Level:** HIGH - Restricts primary access method
**Rollback:** Panic button

### Prerequisites:
- [ ] VPN tunnel verified working
- [ ] SSH via VPN IP (10.200.0.1) verified working
- [ ] Firewall is active with current rules

### Steps:
1. Run panic button
2. Update firewall rule: SSH only from VPN interface/IPs
3. **VERIFY:** SSH via VPN still works
4. **VERIFY:** SSH from WAN is blocked
5. Cancel panic timer if successful

---

## 6. Phase 5: NAT Configuration

**Risk Level:** LOW - Additive change
**Rollback:** Remove NAT table

### Steps:
1. Enable IP forwarding:
   ```bash
   sysctl -w net.ipv4.ip_forward=1
   echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
   ```
2. Add NAT masquerade rule to firewall
3. Add forward chain rules for VPN traffic
4. **VERIFY:** VPN client can reach external resources through gateway

---

## 7. Phase 6: Validation

**Risk Level:** NONE - Read-only
**Rollback:** N/A

### Steps:
1. Run automated compliance tests (tests.sh)
2. Verify all checks pass
3. Document any accepted failures
4. Save final configuration for persistence:
   ```bash
   nft list ruleset > /etc/nftables.conf
   systemctl enable nftables
   ```

---

## 8. Persistence Checklist

After all changes are verified, ensure they survive a reboot:

| Component | Persistence Method | Verify Command |
|-----------|-------------------|----------------|
| Firewall rules | `/etc/nftables.conf` + `systemctl enable nftables` | `nft list ruleset` after reboot |
| VPN | `systemctl enable wg-quick@wg0` | `wg show` after reboot |
| IP forwarding | `/etc/sysctl.conf` | `sysctl net.ipv4.ip_forward` after reboot |
| SSH config | `/etc/ssh/sshd_config` | Direct file, persists |
| Disabled services | `systemctl disable <service>` | Persists |

---

## 9. Emergency Recovery

If all remote access is lost:

1. **Multipass console:** `multipass shell <vm-name>`
2. **Flush firewall:** `nft flush ruleset`
3. **Restore SSH:** Edit `/etc/ssh/sshd_config`, restart sshd
4. **Restart from Phase 3**

---

## 10. Implementation Timeline

| Phase | Description | Dependencies |
|-------|-------------|-------------|
| Phase 1 | System Hardening | None |
| Phase 2 | VPN Deployment | Phase 1 complete |
| Phase 3 | Firewall Deployment | Phase 2 verified |
| Phase 4 | SSH Restriction | Phase 3 verified, VPN confirmed |
| Phase 5 | NAT Configuration | Phase 3 verified |
| Phase 6 | Validation | All phases complete |
