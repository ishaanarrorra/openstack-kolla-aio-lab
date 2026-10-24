# Troubleshooting

Seven problems came up during the deployment. Each was diagnosed from logs, socket inspection or network tests, and fixed without restarting the deployment from scratch.

**Method used every time:** status → logs → ports → config → fix → verify.

| # | Issue | Root cause | Resolution |
|---|---|---|---|
| 1 | Ansible Galaxy returned HTTP 500 | Public outage at galaxy.ansible.com | Installed the collections from their Git repositories |
| 2 | Docker install: "Network is unreachable" | download.docker.com unreachable over IPv4; no IPv6 | Used Ubuntu's docker.io package |
| 3 | Prechecks: Docker SDK missing | Python library not in the venv | Installed `docker` and `dbus-python` with 2026.1 constraints |
| 4 | Prechecks refused quay.io images | Upstream images flagged as test-only | `--use-test-images` |
| 5 | MariaDB: "Address already in use" | ProxySQL and MariaDB both bound port 3306 | Disabled ProxySQL, rebuilt MariaDB |
| 6 | cinder-backup reported down | No backup backend | Disabled the service, removed stale record |
| 7 | Security group wouldn't attach to host VM | Port security disabled on that port | Added rules to the management port's group |

---

## 1. Ansible Galaxy returned HTTP 500

**Symptom:** `kolla-ansible install-deps` failed with HTTP 500 from `galaxy.ansible.com`.

**Diagnosis:** the error came from Galaxy's servers, and Galaxy's status page confirmed a public outage. Nothing was wrong locally.

**Fix:** installed all 7 required collections directly from their Git repositories, pinned to versions compatible with the 2026.1 `requirements.yml`. See [`scripts/01-install-collections-from-git.sh`](../scripts/01-install-collections-from-git.sh).

---

## 2. Docker install failed with "Network is unreachable"

**Symptom:** `bootstrap-servers` failed while adding Docker's upstream apt repository.

**Diagnosis:**

```bash
curl -4 -I https://download.docker.com    # timed out
ping -c 3 download.docker.com             # Network is unreachable
```

The host's network couldn't reach `download.docker.com` over IPv4, and no IPv6 was configured.

**Fix:** used Ubuntu's own `docker.io` package by setting `enable_docker_repo: false` in `globals.yml`.

---

## 3. Prechecks: Docker SDK missing

**Symptom:** `prechecks` failed, reporting the Docker SDK for Python was not found.

**Diagnosis:** Ansible runs inside the virtual environment, and the `docker` Python library wasn't installed there.

**Fix:**

```bash
pip install docker dbus-python -c https://releases.openstack.org/constraints/upper/2026.1
```

---

## 4. Prechecks refused the quay.io images

**Symptom:** `prechecks` refused to continue with the upstream images.

**Diagnosis:** the public images on quay.io are flagged as **test-only** by Kolla.

**Fix:** acknowledged with `kolla-ansible prechecks -i ~/all-in-one --use-test-images`. A production cloud would build images with `kolla-build` and store them in a private registry.

---

## 5. MariaDB crashed with "Address already in use"

**Symptom:** the `mariadb` container kept restarting during `deploy`.

**Diagnosis:**

```bash
docker logs mariadb | tail     # bind on port 3306 failed: Address already in use
sudo ss -tlnp | grep 3306      # proxysql already listening on <MGMT_IP>:3306
```

On a single node, the API address equals the host IP, so **ProxySQL** and **MariaDB** both tried to bind port 3306 on the same address.

**Fix:** set `enable_proxysql: "no"` in `globals.yml` (ProxySQL adds nothing on one node), removed the ProxySQL container and rebuilt MariaDB cleanly with `kolla-ansible deploy`.

---

## 6. cinder-backup reported down

**Symptom:** `openstack volume service list` showed `cinder-backup` as `down`.

**Diagnosis:** no backup backend was configured, so the service could never run.

**Fix:** set `enable_cinder_backup: "no"`, then removed the stale service record:

```bash
docker exec -it cinder_api cinder-manage service remove cinder-backup <hostname>
```

---

## 7. Security group would not attach to the host VM

**Symptom:** on the outer cloud, attaching a security group to the host VM's second port failed.

**Diagnosis:** ports with **port security disabled** cannot take security groups, by design.

**Fix:** added the required rules to the security group already on the **management** port instead.

---

[⬅ Back to README](../README.md)
