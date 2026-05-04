# Oracle Linux 9 local NATS production baseline

This package is for a **local-only** installation. It installs and configures a **standalone** NATS Server on the same Oracle Linux 9 host where you run the bootstrap script.

There is no `inventory.ini` file and no remote SSH execution path. The helper always runs Ansible with:

```bash
-i 'localhost,' --connection=local
```

## Files

- `bootstrap-nats-local.sh` installs `ansible-core` and required base packages on the local Oracle Linux 9 host, then runs the playbook locally.
- `nats-ol9-local-production.yml` installs and hardens NATS Server and the NATS CLI on the local host.

## Local install

```bash
sudo bash bootstrap-nats-local.sh
```

## Local install with overrides

```bash
sudo ANSIBLE_EXTRA_ARGS='-e nats_version=2.14.0 -e nats_max_file_store=100Gb' \
  bash bootstrap-nats-local.sh
```

## External listener behavior

The playbook exposes NATS on the host's **default external IPv4 interface**, based on Ansible facts:

- `nats_external_interface`: defaults to `ansible_default_ipv4.interface`
- `nats_external_address`: defaults to `ansible_default_ipv4.address`
- `nats_client_host`: defaults to `nats_external_address`
- `nats_client_port`: defaults to `4222`

NATS is **not** configured to listen on `0.0.0.0`. It binds to the detected external IPv4 address, for example:

```text
host: "10.0.10.25"
port: 4222
```

If your true external NIC is not the default-route interface, override it explicitly:

```bash
sudo ANSIBLE_EXTRA_ARGS='-e nats_external_interface=ens3 -e nats_external_address=10.0.10.25' \
  bash bootstrap-nats-local.sh
```

## Firewall behavior

The playbook manages firewalld by default:

- Starts and enables `firewalld`.
- Assigns the detected external interface to the `public` zone.
- Sets the `public` zone target to `DROP`.
- Allows only inbound SSH and NATS client traffic:
  - `ssh`
  - `4222/tcp`
- Keeps monitoring bound to `127.0.0.1:8222` and does **not** open it externally.
- Removes other services, ports, source ports, protocols, forward ports, rich rules, and masquerading from the managed external zone when `nats_firewall_purge_extra_rules=true`.

This is intentionally strict. Existing inbound services such as Cockpit, HTTP, HTTPS, database listeners, or custom firewalld rules in the managed external zone will be removed unless you change the firewall variables before running the playbook.

Relevant variables:

```yaml
nats_manage_firewall: true
nats_firewall_zone: public
nats_firewall_purge_extra_rules: true
nats_firewall_allowed_services:
  - ssh
nats_open_monitoring_firewall: false
```

## What the playbook does

- Verifies the machine is Oracle Linux 9.
- Verifies that a usable non-loopback default IPv4 interface/address exists.
- Installs required OS packages.
- Installs a pinned NATS Server release and NATS CLI release.
- Creates a dedicated non-root `nats` system user and group.
- Creates protected directories under `/etc/nats`, `/var/lib/nats`, and `/var/log/nats`.
- Enables TLS by default using a local bootstrap CA and server certificate.
- Generates NATS account passwords once and stores them root-only in `/root/nats-production-secrets.env`.
- Configures JetStream storage under `/var/lib/nats/jetstream`.
- Creates and enables a hardened `systemd` service.
- Starts NATS automatically after reboot.
- Binds NATS client traffic to the external IPv4 address only.
- Configures firewalld to allow inbound SSH and NATS traffic only on the external zone.
- Keeps monitoring bound to `127.0.0.1:8222` by default.
- Installs logrotate configuration for NATS logs.
- Validates that `nats-server` is active and not running as root.
- Validates that NATS is not listening on a wildcard address.
- Validates the runtime firewalld policy.

## Useful commands after installation

```bash
sudo systemctl status nats --no-pager
sudo systemctl is-enabled nats
sudo journalctl -u nats -n 100 --no-pager
sudo cat /root/nats-production-secrets.env
sudo ss -H -ltn sport = :4222
sudo firewall-cmd --zone=public --list-all
```

For a TLS client connection from the same host, source the generated credentials and connect to the external listener address:

```bash
sudo bash -c 'source /root/nats-production-secrets.env; \
  EXTERNAL_IP="$(ip -4 route get 1.1.1.1 | awk "{for(i=1;i<=NF;i++) if(\$i==\"src\"){print \$(i+1); exit}}")"; \
  nats --server "tls://${EXTERNAL_IP}:4222" \
       --tlsca /etc/nats/tls/ca.crt \
       --user "$NATS_APP_USER" \
       --password "$NATS_APP_PASSWORD" \
       server check'
```

For an external TLS client connection, use the external IP or DNS name that matches your certificate/SANs:

```bash
nats --server tls://<external-ip-or-dns>:4222 \
     --tlsca ca.crt \
     --user '<app-user>' \
     --password '<app-password>' \
     server check
```

## Production notes

- The NATS service runs as the dedicated `nats` account, not as root.
- The systemd unit is enabled and uses `Restart=on-failure`, so the service survives reboot and abnormal failure.
- TLS is enabled by default. The default self-signed mode creates a local bootstrap CA and server certificate; replace these with enterprise PKI for formal production.
- NATS account passwords are generated once, stored root-only in `/root/nats-production-secrets.env`, and stored in the NATS config as bcrypt hashes.
- Monitoring is bound to `127.0.0.1:8222` and is not opened in firewalld by default.
- Single-node local NATS can be hardened, but it is not highly available. For HA, use a separate clustered deployment model with at least three servers.
- Set `nats_server_sha256` and `nats_cli_sha256` to approved artifact hashes before regulated production rollout.
