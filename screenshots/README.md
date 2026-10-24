# Screenshots

Evidence that the deployment works end to end.

| File | What it shows |
|---|---|
| `01-horizon-overview.png` | Horizon dashboard, Project → Compute → Overview |
| `02-network-topology.png` | Project → Network → Network Topology: public1, demo-router, demo-net, both VMs |
| `03-instances.png` | Both VMs ACTIVE with private and floating IPs |
| `04-volumes.png` | ubuntu-vol (20 GB) attached to vm2-ubuntu |
| `05-deploy-recap.png` | `kolla-ansible deploy` PLAY RECAP: `ok=344 failed=0` |
| `06-service-status.png` | `openstack compute service list`, `network agent list`, `volume service list` |
| `07-ssh-vm2.png` | SSH into vm2-ubuntu, `lsblk` showing the 20 GB `/dev/vda` |
| `08-docker-ps.png` | `docker ps` listing the Kolla containers |

> All public IP addresses and hostnames are blurred.
