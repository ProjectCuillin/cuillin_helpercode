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
- `bootstrap-nats-local.sh`: Script for setting up a local NATS cluster for development and testing.
- `nats-ol9-local-production.yml`: Example YAML configuration for running NATS on Oracle Linux 9 in a production-like setup.

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
