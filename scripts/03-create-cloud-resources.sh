#!/bin/bash
# Images, flavors, networks, router, security rules and key pair.
# Requires /etc/kolla/clouds.yaml copied to ~/.config/openstack/
set -euo pipefail
export OS_CLOUD=kolla-admin
cd /tmp

# Images
[ -f cirros-0.6.3-x86_64-disk.img ] || wget -q https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img
[ -f noble-server-cloudimg-amd64.img ] || wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

openstack image create cirros-0.6.3 --file cirros-0.6.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --public
openstack image create ubuntu-24.04 --file noble-server-cloudimg-amd64.img \
  --disk-format qcow2 --container-format bare --public

# Flavors
openstack flavor create m1.tiny  --vcpus 1 --ram 512  --disk 1
openstack flavor create m1.small --vcpus 2 --ram 2048 --disk 20

# External provider network on physnet1 (NIC2 -> br-ex)
openstack network create public1 --external \
  --provider-network-type flat --provider-physical-network physnet1
openstack subnet create public1-subnet --network public1 \
  --subnet-range 192.168.100.0/24 --gateway 192.168.100.1 --no-dhcp \
  --allocation-pool start=192.168.100.100,end=192.168.100.200

# Tenant network and router
openstack network create demo-net
openstack subnet create demo-subnet --network demo-net \
  --subnet-range 10.0.0.0/24 --dns-nameserver 8.8.8.8
openstack router create demo-router
openstack router set demo-router --external-gateway public1
openstack router add subnet demo-router demo-subnet

# Security group rules and key pair
openstack security group rule create default --protocol icmp
openstack security group rule create default --protocol tcp --dst-port 22
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
openstack keypair create mykey --public-key ~/.ssh/id_ed25519.pub
