# Deployment Guide

Step-by-step deployment of a single-node OpenStack 2026.1 cloud with Kolla-Ansible, from preparing the host VM to booting two validation VMs. The work ran in nine phases.

> All IP addresses below are placeholders. Replace `<MGMT_IP>` with your host's management IP.

---

## Phase 0 – Infrastructure preparation

**Host VM:** Ubuntu 24.04 · 8 vCPU · 16 GB RAM · 100 GB root disk, created on the outer (production) OpenStack cloud.

### Two NICs with distinct roles

| NIC | Role | IP |
|---|---|---|
| `enp3s0` | Management: SSH, APIs, Horizon | `<MGMT_IP>` |
| `enp8s0` | Handed to Neutron for VM traffic (bridged to `br-ex`) | **none** |

Port security was **disabled** on the second port in the outer cloud. Otherwise the outer cloud's anti-spoofing rules drop traffic coming from the inner cloud's VMs, whose MAC and IP addresses the outer cloud doesn't know about.

### Persist the NIC settings with netplan

See [`config/netplan-example.yaml`](../config/netplan-example.yaml), then:

```bash
sudo netplan apply
ip -br addr   # enp8s0 must be UP with no IP
```

### Stop cloud-init from rewriting network config and /etc/hosts

```bash
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo sed -i 's/^manage_etc_hosts:.*/manage_etc_hosts: false/' /etc/cloud/cloud.cfg
```

### Make the hostname resolve to the real IP

RabbitMQ depends on the hostname resolving to the management IP, not `127.0.1.1`.

```bash
echo "<MGMT_IP> $(hostname)" | sudo tee -a /etc/hosts
getent hosts $(hostname)
```

### Add 4 GB of swap

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Check for nested virtualization

```bash
grep -cE 'vmx|svm' /proc/cpuinfo   # 0 = no hardware virtualization exposed
```

Nested virtualization was unavailable, so the inner cloud uses **QEMU software emulation** instead of KVM.

---

## Phase 1 – Tooling

Installed Kolla-Ansible 22.x (release 2026.1) and ansible-core 2.20 in an isolated Python virtual environment.

```bash
sudo apt update
sudo apt install -y git python3-dev python3-venv libffi-dev gcc libssl-dev

python3 -m venv ~/kolla-venv
source ~/kolla-venv/bin/activate
pip install -U pip
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2026.1

kolla-ansible install-deps
```

> When Ansible Galaxy was down, the collections were installed from Git instead. See [`scripts/01-install-collections-from-git.sh`](../scripts/01-install-collections-from-git.sh) and [troubleshooting](troubleshooting.md#1-ansible-galaxy-returned-http-500).

---

## Phases 2 and 3 – Configuration

```bash
sudo mkdir -p /etc/kolla && sudo chown $USER:$USER /etc/kolla
cp -r ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/all-in-one ~/

kolla-genpwd    # random passwords for every service in /etc/kolla/passwords.yml
```

Key settings in `/etc/kolla/globals.yml` (full example in [`config/globals.yml.example`](../config/globals.yml.example)):

| Setting | Value | Why |
|---|---|---|
| `kolla_base_distro` | `ubuntu` | Ubuntu-based container images |
| `openstack_release` | `2026.1` | Target release |
| `network_interface` | `enp3s0` | Management / API traffic |
| `neutron_external_interface` | `enp8s0` | NIC handed to Neutron (no IP) |
| `kolla_internal_vip_address` | `<MGMT_IP>` | Single node: API address = host IP |
| `enable_haproxy` / `enable_proxysql` | `no` | Not needed on one node; ProxySQL conflicted with MariaDB on port 3306 |
| `nova_compute_virt_type` | `qemu` | No nested KVM |
| `enable_docker_repo` | `false` | Use Ubuntu's docker.io package |

---

## Phase 4 – Deployment

```bash
kolla-ansible bootstrap-servers -i ~/all-in-one              # prepares the host, configures Docker
kolla-ansible prechecks -i ~/all-in-one --use-test-images    # validates ports, interfaces, hostname, config
kolla-ansible pull -i ~/all-in-one                           # downloads ~30 container images
kolla-ansible deploy -i ~/all-in-one                         # 344 tasks
kolla-ansible post-deploy -i ~/all-in-one                    # writes /etc/kolla/admin-openrc.sh
```

`deploy` created the databases, started each service's containers and registered every API endpoint in Keystone.

```
PLAY RECAP
localhost : ok=344  changed=200  unreachable=0  failed=0
```

---

## Phase 5 – Verification

```bash
pip install python-openstackclient -c https://releases.openstack.org/constraints/upper/2026.1
source /etc/kolla/admin-openrc.sh

openstack service list
openstack compute service list    # scheduler, conductor, compute: up
openstack network agent list      # OVS, DHCP, L3, metadata: alive
```

---

## Phase 6 – Block storage (Cinder with LVM)

Attached a 50 GB volume from the outer cloud to the host (`/dev/sdb`) and made it the LVM volume group `cinder-volumes`. See [`scripts/02-setup-cinder-lvm.sh`](../scripts/02-setup-cinder-lvm.sh).

```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
```

Enabled Cinder in `globals.yml` (`enable_cinder`, `enable_cinder_backend_lvm`, `enable_cinder_backup: "no"`) and re-ran:

```bash
kolla-ansible deploy -i ~/all-in-one
openstack volume service list    # cinder-scheduler and cinder-volume@lvm-1: up
```

Kolla set up a **thin-provisioned pool**, so volumes use real space only as data is written. `cinder-backup` was disabled because the lab has no backup target.

---

## Phase 7 – Cloud configuration (CLI)

All done with the OpenStack CLI. See [`scripts/03-create-cloud-resources.sh`](../scripts/03-create-cloud-resources.sh).

| Resource | Details |
|---|---|
| Images | CirrOS 0.6.3, Ubuntu 24.04 cloud image |
| Flavors | `m1.tiny` (1 vCPU, 512 MB, 1 GB) · `m1.small` (2 vCPU, 2 GB, 20 GB) |
| `public1` | Flat external provider network on `physnet1` (NIC2), floating IP pool 192.168.100.100–200 |
| `demo-net` | Tenant network 10.0.0.0/24 |
| `demo-router` | NAT between `demo-net` and `public1` |
| Security | Default group rules for ICMP and SSH; SSH key pair registered |

---

## Phase 8 – Validation

See [`scripts/04-launch-demo-vms.sh`](../scripts/04-launch-demo-vms.sh).

- **vm1-cirros:** booted from the image onto an **ephemeral disk** (1 GB from the flavor).
- **vm2-ubuntu:** a 20 GB **bootable Cinder volume** was created from the Ubuntu image first, then the VM booted from it, with a cloud-init script ([`config/cloud-init-ubuntu.yaml`](../config/cloud-init-ubuntu.yaml)) setting the console password. Boot took 158 s under QEMU emulation.

Both VMs got private IPs by DHCP and floating IPs through the router, and both answered **ping** and **key-based SSH**.

To test floating IPs from the host, give `br-ex` an address on the external network (this does not survive a reboot):

```bash
sudo ip addr add 192.168.100.5/24 dev br-ex
ping -c 3 <FLOATING_IP>
ssh cirros@<FLOATING_IP>
```

---

## Lab notes

- Re-run `prechecks` with `--use-test-images`; `pull` and `deploy` do not take that flag.
- Horizon: **Project → Network → Network Topology** gives a visual of the inner cloud, useful for demos.

---

[⬅ Back to README](../README.md)
