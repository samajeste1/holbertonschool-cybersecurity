# Access Control Models: DAC, RBAC & MAC

## Description

Security architecture project for SecureHealth, a regional hospital network. Implements access control remediation across four layers:

1. **DAC** - Discretionary Access Control: File permissions and ACLs
2. **RBAC** - Role-Based Access Control: Role matrix with least privilege
3. **MAC** - Mandatory Access Control: AppArmor application confinement
4. **Defense in Depth** - Layered security architecture

## Environment

- Ubuntu 22.04+ / Kali / ParrotOS
- AppArmor (installed by default on Ubuntu)

## Tools

- `chmod`, `chown`, `setfacl`, `getfacl`
- `apparmor_parser`, `aa-status`, `aa-enforce`, `aa-complain`

## Author

samajeste1
