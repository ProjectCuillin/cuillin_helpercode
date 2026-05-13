# Local NATS production baseline

This package is for a **local-only** installation. It installs and configures a **standalone** NATS Server on the same Oracle Linux or Debian host where you run the bootstrap script.

There is no `inventory.ini` file and no remote SSH execution path. The helper always runs Ansible with:

```bash
-i 'localhost,' --connection=local
```

## Files

- `bootstrap-nats-local.sh` detects Oracle Linux versus Debian, installs `ansible-core` and required base packages with the native package manager, then runs the playbook locally.
- `nats-local-production.yml` installs and hardens NATS Server and the NATS CLI on the local host.
- `nats-ol9-local-production.yml` is a backward-compatible wrapper that imports `nats-local-production.yml`.

## Supported platforms

- Oracle Linux hosts using `dnf`.
- Debian hosts using `apt`.

The bootstrap script and playbook fail early on other operating systems.

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
- `nats_monitor_host`: defaults to `nats_client_host`
- `nats_monitor_port`: defaults to `8222`

NATS is **not** configured to listen on `0.0.0.0`. The client and monitoring listeners bind to the detected external IPv4 address, for example:

```text
host: "10.0.10.25"
port: 4222
http: "10.0.10.25:8222"
```

If your true external NIC is not the default-route interface, override it explicitly:

```bash
sudo ANSIBLE_EXTRA_ARGS='-e nats_external_interface=ens3 -e nats_external_address=10.0.10.25' \
  bash bootstrap-nats-local.sh
```

## Firewall behavior

The playbook manages firewalld by default:

- Starts and enables `firewalld`.
- Assigns the detected external interface to the dedicated `nats-external` zone.
- Sets the `nats-external` zone target to `DROP`.
- Allows only inbound SSH and NATS traffic:
  - `ssh`
  - `4222/tcp`
  - `8222/tcp`
- Adds the NATS route port `6222/tcp` only when `nats_cluster_enabled=true`.
- Opens the monitoring port `8222/tcp` when `nats_open_monitoring_firewall=true`, which is the default.
- Removes other services, ports, source ports, protocols, forward ports, rich rules, and masquerading from the managed external zone.

This is intentionally strict. Existing inbound services such as Cockpit, HTTP, HTTPS, database listeners, or custom firewalld rules in the managed external zone will be removed unless you change the firewall variables before running the playbook. On Debian, this baseline standardizes on `firewalld` as the local firewall manager.

Relevant variables:

```yaml
nats_manage_firewall: true
nats_firewall_zone: nats-external
nats_firewall_allowed_services:
  - ssh
nats_firewall_nats_ports:
  - 4222/tcp
  - 8222/tcp
nats_firewall_allowed_ports:
  - 4222/tcp
  - 8222/tcp
nats_open_monitoring_firewall: true
```

## TLS certificates

TLS is enabled by default. The playbook supports three certificate modes through `nats_tls_certificate_mode`:

- `auto`: Uses provided certificate files when all required files are present; otherwise generates a local self-signed bootstrap CA and server certificate. This is the default.
- `provided`: Requires CA-issued or official certificate files and fails if they are missing.
- `self_signed`: Uses or generates the local self-signed bootstrap CA and server certificate.

The required runtime files are:

```yaml
nats_tls_ca_file: /etc/nats/tls/ca.crt
nats_tls_cert_file: /etc/nats/tls/server.crt
nats_tls_key_file: /etc/nats/tls/server.key
```

In `auto` mode, the playbook uses those files when all three already exist. If none exist, it generates self-signed files. If only some of the files exist, the playbook fails so it does not accidentally mix an official certificate with generated material.

For self-signed TLS, copy **only the CA certificate** from the server to your workstation. The file you need is:

```text
/etc/nats/tls/ca.crt
```

Do not copy `/etc/nats/tls/server.key` or `/etc/nats/tls/ca.key` to your workstation. Those are private keys. You also normally do not use `server.crt` with the NATS CLI; the client needs the CA certificate that signed the server certificate.

One safe way to copy the self-signed CA certificate to your workstation is:

```bash
ssh <admin-user>@<nats-server> 'sudo cat /etc/nats/tls/ca.crt' > nats-ca.crt
chmod 0644 nats-ca.crt
```

Then use that CA certificate with the remote NATS CLI:

```bash
nats --server tls://<external-ip-or-dns>:4222 \
     --tlsca ./nats-ca.crt \
     --user '<app-user>' \
     --password '<app-password>' \
     server check connection
```

The app username and password are generated on the server in `/root/nats-production-secrets.env`.

To use a CA-issued or official certificate, make sure the certificate contains a SAN for the external DNS name or IP address clients will use. Then either preinstall the files at the runtime paths above, or provide source paths for the playbook to copy:

```bash
sudo ANSIBLE_EXTRA_ARGS="-e nats_tls_certificate_mode=provided \
  -e nats_tls_provided_cert_source=/root/nats-certs/fullchain.pem \
  -e nats_tls_provided_key_source=/root/nats-certs/privkey.pem \
  -e nats_tls_provided_ca_source=/root/nats-certs/ca-chain.pem" \
  bash bootstrap-nats-local.sh
```

The playbook copies those source files into `/etc/nats/tls/server.crt`, `/etc/nats/tls/server.key`, and `/etc/nats/tls/ca.crt`, then sets service-readable permissions for the `nats` user.

If the official certificate chains to a public CA trusted by your workstation, the NATS CLI may work without `--tlsca`. For private enterprise CAs, use the enterprise CA bundle with `--tlsca`:

```bash
nats --server tls://<external-dns-name>:4222 \
     --tlsca ./enterprise-ca-chain.pem \
     --user '<app-user>' \
     --password '<app-password>' \
     server check connection
```

## What the playbook does

- Verifies the machine is Oracle Linux or Debian.
- Verifies that the service account is exactly `nats:nats`.
- Verifies that firewall allowlists contain only SSH and the enabled NATS ports.
- Verifies that a usable non-loopback default IPv4 interface/address exists.
- Verifies that externally exposed monitoring binds to the same address as the NATS client listener.
- Installs required OS packages.
- Installs a pinned NATS Server release and NATS CLI release.
- Creates the `nats` group and creates the non-root `nats` service user only when it does not already exist.
- Reuses an existing non-root `nats` user without changing its home directory, shell, or comment.
- Creates protected directories under `/etc/nats`, `/var/lib/nats`, and `/var/log/nats`.
- Enables TLS by default, using provided CA-issued certificate files when present or generating a local bootstrap CA and server certificate when not.
- Generates NATS account passwords once and stores them root-only in `/root/nats-production-secrets.env`.
- Configures JetStream storage under `/var/lib/nats/jetstream`.
- Validates the generated NATS configuration as the `nats` user.
- Creates and enables a hardened `systemd` service.
- Starts NATS automatically after reboot.
- Binds NATS client traffic to the external IPv4 address only.
- Binds NATS monitoring traffic to the same external IPv4 address by default.
- Configures firewalld to allow inbound SSH and NATS traffic only on the external zone.
- Installs logrotate configuration for NATS logs.
- Validates that `nats-server` is active and not running as root.
- Validates that the `systemd` unit is enabled for reboot persistence and configured with `User=nats` and `Group=nats`.
- Validates that NATS is not listening on a wildcard address.
- Validates the runtime firewalld policy contains only the allowed SSH service and NATS ports.

## Verify the installation

Run these checks on the NATS server first:

```bash
sudo systemctl is-active nats
sudo systemctl is-enabled nats
ps -o user,pid,cmd -C nats-server
sudo journalctl -u nats -n 100 --no-pager
sudo ss -H -ltn sport = :4222
sudo ss -H -ltn sport = :8222
sudo firewall-cmd --zone=nats-external --list-all
```

Expected results:

- `systemctl is-active nats` returns `active`.
- `systemctl is-enabled nats` returns `enabled`.
- `ps` shows `nats-server` running as user `nats`, not `root`.
- `ss` shows `4222` and `8222` listening on the host's external IPv4 address.
- `firewall-cmd` shows service `ssh` and ports `4222/tcp 8222/tcp` in the `nats-external` zone.

Check the local monitoring endpoint from the NATS server:

```bash
SERVER_IP="$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
curl -fsS "http://${SERVER_IP}:8222/healthz"
```

Check a TLS NATS client connection from the NATS server:

```bash
sudo bash -c 'source /root/nats-production-secrets.env; \
  SERVER_IP="$(ip -4 route get 1.1.1.1 | awk "{for(i=1;i<=NF;i++) if(\$i==\"src\"){print \$(i+1); exit}}")"; \
  nats --server "tls://${SERVER_IP}:4222" \
       --tlsca /etc/nats/tls/ca.crt \
       --user "$NATS_APP_USER" \
       --password "$NATS_APP_PASSWORD" \
       server check connection'
```

Check JetStream from the NATS server:

```bash
sudo bash -c 'source /root/nats-production-secrets.env; \
  SERVER_IP="$(ip -4 route get 1.1.1.1 | awk "{for(i=1;i<=NF;i++) if(\$i==\"src\"){print \$(i+1); exit}}")"; \
  nats --server "tls://${SERVER_IP}:4222" \
       --tlsca /etc/nats/tls/ca.crt \
       --user "$NATS_APP_USER" \
       --password "$NATS_APP_PASSWORD" \
       server check jetstream'
```

From another machine on a network that should be allowed to reach this server, check external TCP reachability:

```bash
SERVER_IP=<nats-server-ip-or-dns>
nc -vz "$SERVER_IP" 4222
nc -vz "$SERVER_IP" 8222
curl -fsS "http://${SERVER_IP}:8222/healthz"
```

For an external TLS NATS client connection, use the external IP or DNS name that matches your certificate/SANs. With the default self-signed bootstrap certificate, use the `nats-ca.crt` file copied in the TLS section above. With an official or enterprise certificate, use the issuing CA bundle when it is not already trusted by your workstation:

```bash
nats --server tls://<external-ip-or-dns>:4222 \
     --tlsca ./nats-ca.crt \
     --user '<app-user>' \
     --password '<app-password>' \
     server check connection
```

If you want to prove publish/subscribe flow end-to-end from a client host, start a subscription in one terminal:

```bash
nats --server tls://<external-ip-or-dns>:4222 \
     --tlsca ./nats-ca.crt \
     --user '<app-user>' \
     --password '<app-password>' \
     sub cuillin.test
```

Then publish from another terminal:

```bash
nats --server tls://<external-ip-or-dns>:4222 \
     --tlsca ./nats-ca.crt \
     --user '<app-user>' \
     --password '<app-password>' \
     pub cuillin.test 'hello from external client'
```

## Production notes

- The NATS service runs as the dedicated `nats` account, not as root.
- The playbook fails if `nats_user` or `nats_group` is changed away from `nats`.
- If a `nats` user already exists, the playbook validates that it is not uid 0 and leaves the account metadata untouched.
- The systemd unit is enabled and uses `Restart=on-failure`, so the service survives reboot and abnormal failure.
- TLS is enabled by default. In `auto` mode, the playbook uses complete provided certificate files when present and otherwise creates a local bootstrap CA and server certificate.
- NATS account passwords are generated once, stored root-only in `/root/nats-production-secrets.env`, and stored in the NATS config as bcrypt hashes.
- Monitoring is bound to the same external IPv4 address as the NATS client listener and is opened in firewalld by default.
- NATS monitoring endpoints are unauthenticated HTTP endpoints; expose them only on trusted networks and restrict upstream cloud or network security rules accordingly.
- Single-node local NATS can be hardened, but it is not highly available. For HA, use a separate clustered deployment model with at least three servers.
- Set `nats_server_sha256` and `nats_cli_sha256` to approved artifact hashes before regulated production rollout.
