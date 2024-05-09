nixfiles
========

My [NixOS][] configuration and assorted other crap, powered by [flakes][].
Clone to `/etc/nixos`.

CI checks ensure that code is formatted and passes linting.  Run those locally
with:

```bash
nix flake check
nix run .#fmt
nix run .#lint
```

See [the documentation](https://nixfiles.docs.barrucadu.co.uk).

[NixOS]: https://nixos.org
[flakes]: https://wiki.nixos.org/wiki/Flakes


Overview
--------

This is an opinionated config making assumptions which work for me but might not
for you:

- These are primarily single-user hosts, with me being that user.  While
  security and availability are important, convenience takes priority.
- Observability is good but there's no central graphing or alerting stack, every
  host has to run their own.
- Databases should not be shared, each service has its own containerised
  instance.  This means a single host may run several instances of the same
  database software, but that's an acceptable overhead.
- Persistent docker volumes should be backed by bind-mounts to the filesystem.
- For ZFS systems, [wiping `/` on boot][] is good actually.

Everything in `shared/default.nix` is **enabled on every host by default**.
Notable decisions are:

- Every user gets a `~/tmp` directory with files cleaned out after 7 days.
- Automatic upgrades (including reboots if needed), automatic deletions of
  generations older than 30 days, and automatic garbage collection are all
  enabled.
- Locale, timezone, and keyboard layout all set to UK / GB values (yes, even on
  servers).
- Firewall and fail2ban are enabled, but pings are explicitly allowed.
- SSH accepts pubkey auth only: no passwords.
- Syncthing is enabled.

For monitoring and alerting specifically:

- Prometheus, Grafana, and Alertmanager are all enabled by default (Alertmanager
  needs AWS credentials provided to actually send alerts).
- The Node Exporter is enabled, along with a dashboard.
- cAdvisor is enabled, along with a dashboard.

If using ZFS there are a few more things configured:

- All pools are scrubbed monthly.
- The auto-trim and auto-snapshot jobs are enabled (for pools which have those
  configured).
- There's a Prometheus alert for pools in a state other than "online".

Everything else in `shared/` is available to every host, but disabled by
default.

[wiping `/` on boot]: https://grahamc.com/blog/erase-your-darlings


Tools
-----

### Backups

Backups are managed by `shared/restic-backups` and uploaded to [Backblaze B2][]
with [restic][].

List all the snapshots with:

```bash
nix run .#backups                                # all snapshots
nix run .#backups -- snapshots --host <hostname> # for a specific host
nix run .#backups -- snapshots --tag <tag>       # for a specific tag
```

Restore a snapshot to `<restore-dir>` with:

```bash
nix run .#backups restore <snapshot> [<restore-dir>]
```

If unspecified, the snapshot is restored to `/tmp/restic-restore-<snapshot>`.

[Backblaze B2]: https://www.backblaze.com/
[restic]: https://restic.net/

### Secrets

Secrets are managed with [sops-nix][].  Create / edit secrets with:

```bash
nix run .#secrets                   # secrets.yaml for current host
nix run .#secrets <hostname>        # secrets.yaml for <hostname>
nix run .#secrets <hostname> <name> # <name>.yaml for <hostname>
```

[sops-nix]: https://github.com/Mic92/sops-nix
