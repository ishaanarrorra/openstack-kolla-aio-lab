#!/bin/bash
# Create the LVM volume group used by the Cinder LVM backend.
# WARNING: wipes the target disk. Check with lsblk first.
# Usage: DISK=/dev/sdb ./02-setup-cinder-lvm.sh
set -euo pipefail
DISK="${DISK:-/dev/sdb}"
VG="cinder-volumes"

lsblk "$DISK"
read -rp "Use $DISK for $VG? All data on it will be lost [y/N] " ans
[[ "$ans" == "y" ]] || exit 1

sudo pvcreate "$DISK"
sudo vgcreate "$VG" "$DISK"
sudo vgs "$VG"

echo "Now set enable_cinder and enable_cinder_backend_lvm in globals.yml"
echo "and run: kolla-ansible deploy -i ~/all-in-one"
