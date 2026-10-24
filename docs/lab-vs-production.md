# Lab vs. Production

The lab proves the workflow. A production cloud changes the topology, the hypervisor, the image supply chain, storage and security.

| Area | This lab | Production |
|---|---|---|
| **Topology** | 1 node, everything together | 3 or more controllers for high availability, separate compute and storage nodes |
| **Load balancing** | HAProxy and ProxySQL off | HAProxy with keepalived and a virtual IP; ProxySQL in front of the Galera database cluster |
| **Hypervisor** | QEMU, emulated | KVM on bare metal |
| **Images** | Public test images from quay.io | Built with `kolla-build` and stored in a private registry |
| **Storage** | LVM on one disk | Ceph, replicated and self-healing |
| **Security** | Plain HTTP, access limited by source IP | TLS everywhere, Horizon behind a VPN |
| **Networking** | One flat external network | VLAN or VXLAN provider networks, often OVN, redundant uplinks |

## Why these differences matter

- **High availability:** a single controller is a single point of failure. Three controllers let MariaDB (Galera) and RabbitMQ keep quorum when one node fails.
- **Performance:** QEMU emulation is many times slower than KVM; the Ubuntu VM took 158 s to boot in this lab.
- **Supply chain:** building images in-house means you control exactly what runs in production and can patch it.
- **Data durability:** LVM on one disk loses every volume if that disk fails; Ceph keeps multiple replicas across nodes.

---

[⬅ Back to README](../README.md)
