#!/usr/bin/env bash
set -euo pipefail

# Local-only bootstrap helper for Oracle Linux 9.
# Purpose:
#   1. Verify this host is Oracle Linux 9.
#   2. Install ansible-core and required base tooling using dnf.
#   3. Run the NATS production baseline playbook against this same host only.
#
# Usage:
#   sudo bash bootstrap-nats-local.sh
#
# Optional environment overrides:
#   PLAYBOOK=./nats-ol9-local-production.yml
#   ANSIBLE_EXTRA_ARGS='-e nats_version=2.14.0 -e nats_max_file_store=100Gb'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK="${PLAYBOOK:-${SCRIPT_DIR}/nats-ol9-local-production.yml}"
ANSIBLE_EXTRA_ARGS="${ANSIBLE_EXTRA_ARGS:-}"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: Run as root or install sudo first." >&2
    exit 1
  fi
  SUDO="sudo"
fi

if [[ ! -r /etc/os-release ]]; then
  echo "ERROR: /etc/os-release not found; cannot verify operating system." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-}"
OS_VERSION_MAJOR="${VERSION_ID%%.*}"

if [[ "${OS_ID}" != "ol" || "${OS_VERSION_MAJOR}" != "9" ]]; then
  echo "ERROR: This bootstrap script is intended for Oracle Linux 9. Detected ID='${OS_ID}' VERSION_ID='${VERSION_ID:-unknown}'." >&2
  exit 1
fi

if [[ ! -f "${PLAYBOOK}" ]]; then
  echo "ERROR: Playbook not found: ${PLAYBOOK}" >&2
  exit 1
fi

echo "Installing Ansible and required base packages on this Oracle Linux 9 host..."
${SUDO} dnf makecache -y
${SUDO} dnf install -y \
  ansible-core \
  python3 \
  python3-libselinux \
  ca-certificates \
  curl \
  tar \
  gzip \
  unzip \
  openssl \
  firewalld \
  logrotate \
  policycoreutils-python-utils \
  iproute

ansible --version

echo "Running the local-only NATS Ansible playbook on this host..."
# Intentional word-splitting for ANSIBLE_EXTRA_ARGS so callers can pass normal Ansible flags.
# shellcheck disable=SC2086
ansible-playbook \
  -i 'localhost,' \
  --connection=local \
  "${PLAYBOOK}" \
  --become \
  ${ANSIBLE_EXTRA_ARGS}

echo "NATS local installation completed. Check service status with: systemctl status nats --no-pager"
