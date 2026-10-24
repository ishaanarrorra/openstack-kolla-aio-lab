#!/bin/bash
# Pre-flight checks before running Kolla-Ansible on a single node.
# Usage: MGMT_IP=<your-ip> ./00-preflight-check.sh
set -u
MGMT_NIC="${MGMT_NIC:-enp3s0}"
EXT_NIC="${EXT_NIC:-enp8s0}"
: "${MGMT_IP:?Set MGMT_IP to the host management IP}"
fail=0
check() { if eval "$2" &>/dev/null; then echo "[ OK ] $1"; else echo "[FAIL] $1"; fail=1; fi; }

check "Management NIC $MGMT_NIC has $MGMT_IP"   "ip -4 addr show $MGMT_NIC | grep -q '$MGMT_IP'"
check "External NIC $EXT_NIC exists"            "ip link show $EXT_NIC"
check "External NIC $EXT_NIC has no IPv4"       "! ip -4 addr show $EXT_NIC | grep -q inet"
check "Hostname resolves to $MGMT_IP"           "getent hosts \$(hostname) | grep -q '$MGMT_IP'"
check "At least 16 GB RAM (incl. swap)"         "[ \$(free -g | awk '/Mem/{m=\$2}/Swap/{s=\$2}END{print m+s}') -ge 16 ]"
check "Python venv active"                      "[ -n \"\${VIRTUAL_ENV:-}\" ]"
check "kolla-ansible installed"                 "command -v kolla-ansible"

if grep -qE 'vmx|svm' /proc/cpuinfo; then
  echo "[INFO] Hardware virtualization available: nova_compute_virt_type can be kvm"
else
  echo "[INFO] No hardware virtualization: use nova_compute_virt_type: qemu"
fi

exit $fail
