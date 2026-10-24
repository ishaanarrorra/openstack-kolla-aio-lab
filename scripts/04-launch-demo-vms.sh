#!/bin/bash
# vm1-cirros: ephemeral disk. vm2-ubuntu: boots from a Cinder volume.
set -euo pipefail
export OS_CLOUD=kolla-admin
USERDATA="${USERDATA:-$(dirname "$0")/../config/cloud-init-ubuntu.yaml}"

# vm1: ephemeral disk from the flavor
openstack server create vm1-cirros --flavor m1.tiny --image cirros-0.6.3 \
  --network demo-net --key-name mykey --wait

# vm2: bootable 20 GB Cinder volume created from the image
openstack volume create ubuntu-vol --image ubuntu-24.04 --size 20 --bootable
until [ "$(openstack volume show ubuntu-vol -f value -c status)" = "available" ]; do sleep 5; done
openstack server create vm2-ubuntu --flavor m1.small --volume ubuntu-vol \
  --network demo-net --key-name mykey --user-data "$USERDATA" --wait

# Floating IPs
for vm in vm1-cirros vm2-ubuntu; do
  fip=$(openstack floating ip create public1 -f value -c floating_ip_address)
  openstack server add floating ip "$vm" "$fip"
  echo "$vm -> $fip"
done
