# Cuillin Helper Code

This repository contains a growing collection of installation scripts, helper utilities, test scripts, and other useful tools supporting projects under the [Cuillin](https://github.com/cuillin-project) umbrella.
The goal is to provide reusable scripts and configurations that simplify common development, deployment, and testing workflows.

## Repository Structure

- **NATS/**  
  Helper scripts, bootstrap utilities, and example configurations related to [NATS](https://nats.io/), a high-performance messaging system.
  - See [NATS/README.md](./NATS/README.md) for detailed usage and explanations of the available NATS-related scripts.
- *(More categories and scripts coming soon!)*

## NATS Helpers

The [`NATS/`](./NATS) directory includes:
- `bootstrap-nats-local.sh`: Local bootstrap script that detects Oracle Linux or Debian, installs the required base packages and Ansible tooling, then runs the NATS production baseline against the same host.
- `nats-local-production.yml`: Ansible playbook for a hardened standalone NATS Server installation with TLS, JetStream, generated credentials, external NATS monitoring, a dedicated non-root `nats` service user, a reboot-persistent `systemd` service, and strict `firewalld` rules that expose only SSH and enabled NATS ports. If the `nats` user already exists, the playbook reuses it without changing the active account metadata.
- `nats-ol9-local-production.yml`: Backward-compatible wrapper that imports `nats-local-production.yml`.

The NATS baseline is designed for a local single-node production-style installation on Oracle Linux or Debian. It explicitly prevents NATS from running as root, enables the service on boot, binds client traffic to the detected external IPv4 address rather than `0.0.0.0`, and validates the runtime firewall policy after installation.

For a full description and instructions, see the [NATS/README.md](./NATS/README.md).

## Getting Started

1. Clone this repository:
    ```sh
    git clone https://github.com/cuillin-project/cuillin_helpercode.git
    cd cuillin_helpercode
    ```

2. Browse the available scripts and helpers in each directory.
3. Follow the instructions within each subdirectory's README or script headers for usage details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have a useful script or improvement to contribute.

## License

This repository is licensed under the terms of the [MIT License](./LICENSE).
