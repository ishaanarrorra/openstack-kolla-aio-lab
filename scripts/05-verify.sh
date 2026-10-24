#!/bin/bash
# Verify services, agents, volumes and VM reachability.
set -u
export OS_CLOUD=kolla-admin

echo "== Compute services ==";  openstack compute service list
echo "== Network agents ==";    openstack network agent list
echo "== Volume services ==";   openstack volume service list
echo "== Servers ==";           openstack server list
echo "== Volumes ==";           openstack volume list

# The host needs an address on the external network to reach floating IPs
ip addr show br-ex | grep -q 192.168.100.5 || sudo ip addr add 192.168.100.5/24 dev br-ex

for fip in $(openstack floating ip list -f value -c "Floating IP Address"); do
  if ping -c 2 -W 2 "$fip" &>/dev/null; then echo "[ OK ] ping $fip"; else echo "[FAIL] ping $fip"; fi
done
