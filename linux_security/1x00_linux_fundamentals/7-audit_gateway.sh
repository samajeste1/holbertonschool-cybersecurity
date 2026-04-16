#!/bin/bash
setfacl -m u:auditor:r /var/log/app && getfacl /var/log/app
