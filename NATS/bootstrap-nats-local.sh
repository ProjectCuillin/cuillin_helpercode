#!/usr/bin/env bash
set -euo pipefail

# Local-only bootstrap helper for Oracle Linux and Debian
# Purpose:
#   1. Verify this host is Oracle Linux or Debian.
#   2. Install ansible-core and required base tooling using the native package manager.
#   3. Run the NATS production baseline playbook against this same host only.
#
# Usage:
#   sudo bash bootstrap-nats-local.sh
#
# Optional environment overrides:
#   PLAYBOOK=./nats-local-production.yml
#   ANSIBLE_EXTRA_ARGS='-e nats_version=2.14.0 -e nats_max_file_store=100Gb'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYBOOK="${PLAYBOOK:-${SCRIPT_DIR}/nats-local-production.yml}"
ANSIBLE_EXTRA_ARGS="${ANSIBLE_EXTRA_ARGS:-}"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: Run as root or install sudo first." >&2
    exit 1
  fi
  SUDO="sudo"
fi

run_as_root() {
  if [[ -n "${SUDO}" ]]; then
    "${SUDO}" "$@"
  else
    "$@"
  fi
}

if [[ ! -r /etc/os-release ]]; then
  echo "ERROR: /etc/os-release not found; cannot verify operating system." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
OS_ID="${ID:-}"
OS_PRETTY_NAME="${PRETTY_NAME:-${OS_ID} ${VERSION_ID:-}}"

if [[ "${OS_ID}" != "ol" && "${OS_ID}" != "debian" ]]; then
  echo "ERROR: This bootstrap script supports Oracle Linux and Debian only. Detected ID='${OS_ID}' VERSION_ID='${VERSION_ID:-unknown}'." >&2
  exit 1
fi

if [[ ! -f "${PLAYBOOK}" ]]; then
  echo "ERROR: Playbook not found: ${PLAYBOOK}" >&2
  exit 1
fi

echo "Detected ${OS_PRETTY_NAME}. Installing Ansible and required base packages..."
case "${OS_ID}" in
  ol)
    if ! command -v dnf >/dev/null 2>&1; then
      echo "ERROR: Oracle Linux host does not have dnf available." >&2
      exit 1
    fi

    run_as_root dnf makecache -y
    run_as_root dnf install -y \
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
      iproute \
      util-linux
    ;;
  debian)
    if ! command -v apt-get >/dev/null 2>&1; then
      echo "ERROR: Debian host does not have apt-get available." >&2
      exit 1
    fi

    run_as_root apt-get update
    if apt-cache show ansible-core >/dev/null 2>&1; then
      ANSIBLE_PACKAGE="ansible-core"
    else
      ANSIBLE_PACKAGE="ansible"
    fi

    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
      "${ANSIBLE_PACKAGE}" \
      python3 \
      python3-apt \
      ca-certificates \
      curl \
      tar \
      gzip \
      unzip \
      openssl \
      firewalld \
      logrotate \
      iproute2 \
      util-linux
    ;;
esac

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "ERROR: ansible-playbook was not installed or is not on PATH." >&2
  exit 1
fi

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
