#!/bin/bash
setfacl -d -m u:auditor:r /var/log/app && getfacl /var/log/app
