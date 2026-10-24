#!/bin/bash
# Fallback for "kolla-ansible install-deps" when Ansible Galaxy is down.
# openstack.kolla installs from opendev.org; the other 7 collections are
# installed directly from their GitHub repositories, pinned to the versions
# used in this lab (compatible with the 2026.1 requirements.yml).
set -euo pipefail

collections=(
  "git+https://opendev.org/openstack/ansible-collection-kolla.git,stable/2026.1"
  "git+https://github.com/ansible-collections/ansible.netcommon.git,v8.7.1"
  "git+https://github.com/ansible-collections/ansible.posix.git,2.2.2"
  "git+https://github.com/ansible-collections/ansible.utils.git,v6.1.1"
  "git+https://github.com/ansible-collections/community.crypto.git,3.5.1"
  "git+https://github.com/ansible-collections/community.docker.git,4.8.9"
  "git+https://github.com/ansible-collections/community.general.git,11.4.9"
  "git+https://github.com/containers/ansible-podman-collections.git,1.21.2"
)

for c in "${collections[@]}"; do
  echo ">>> Installing $c"
  ansible-galaxy collection install "$c"
done

ansible-galaxy collection list
