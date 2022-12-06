nixfiles
========

My [NixOS][] configuration and assorted other crap, powered by [flakes][].
Clone to `/etc/nixos`.

[NixOS]: https://nixos.org
[flakes]: https://nixos.wiki/wiki/Flakes


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

### Hosts

Currently I have 4 machines.  The naming convention is:

- **Local machines:** beings (gods, people, etc) of the Cthulhu Mythos.
- **Remote machines:** places of the Cthulhu Mythos.

#### azathoth

This is my desktop computer.

It dual-boots Windows 10 and NixOS, so it doesn’t run any services, as they
won't be accessible half of the time.  I don't bother backing up either OS:
everything I care about is in Syncthing, on GitHub, or on some other cloud
service (eg, Steam).

#### carcosa

This is a VPS (hosted by Hetzner Cloud).

It serves [barrucadu.co.uk][] and other services on it, such as [a bookdb
instance][] and [my blog][].  Websites are served with Caddy, with certs from
Let's Encrypt.

It's set up in "erase your darlings" style, so most of the filesystem is wiped
on boot and restored from the configuration, to ensure there's no accidentally
unmanaged configuration or state hanging around.

[barrucadu.co.uk]: https://www.barrucadu.co.uk/
[a bookdb instance]: https://bookdb.barrucadu.co.uk/
[my blog]: https://memo.barrucadu.co.uk/

#### lainonlife

This is a dedicated server (hosted by Kimsufi).

It serves the Lainchan radio (powered by MPD and Icecast) on [lainon.life][] and
a Pleroma instance on [social.lainon.life][].  Like carcosa, it uses Caddy and
Let's Encrypt.  This is the only multi-user host in my configuration.

This machine disables syncthing, as I don't really SSH into it.

[lainon.life]: https://lainon.life/
[social.lainon.life]: https://social.lainon.life/

#### nyarlathotep

This is my home server.

It runs writable instances of the bookdb and bookmarks servers, which have any
updates copied across to carcosa hourly; it acts as a NAS; and it runs a few
utility services, such as a dashboard of finance information from my hledger
journal, and a script to automatically tag and organise new podcast episodes or
CD rips which I copy over to it.

Like carcosa, this host is set up in "erase your darlings" style but, unlike
carcosa, it automatically reboots to install updates: so that takes effect
significantly more frequently.


Development
-----------

CI checks ensure that code is formatted and passes linting.  Run those locally
with:

```bash
nix run .\#fmt
nix run .\#lint
```

### Adding a new host

Set up the host with the standard NixOS installer, to generate a suitable
`configuration.nix` and `hardware-configuration.nix`, then:

1. Clone this repo
2. Move the generated files to `hosts/<hostname>/configuration.nix` and `hosts/<hostname>/hardware.nix`
3. Edit them as needed
4. Add an entry for the host to `flake.nix`
5. Build the new system configuration with `sudo nixos-rebuild switch --flake '.#<hostname>'`
6. Reboot
7. Generate an ed25519 SSH key
8. Add the public key to GitHub and to anywhere else needed (eg, `shared/default.nix`)
9. Commit
10. Push

**If this is a ZFS-using system:** create the following datasets:

- `local/volatile/root`, mounted to `/`
- `local/persistent/home`, mounted to `/home`
- `local/persistent/nix`, mounted to `/nix`
- `local/persistent/persist`, mounted to `/persist`
- `local/persistent/var-log`, mounted to `/var/log`

Take a snapshot of the root dataset before installing NixOS to it:

```bash
zfs snapshot local/volatile/root@blank
```

And then in your configuration use `nixfiles.eraseYourDarlings`

### Editing secrets

Secrets are managed with [sops-nix][].  Create / edit secrets with:

```bash
nix run .\#secrets                   # secrets.yaml for current host
nix run .\#secrets <hostname>        # secrets.yaml for <hostname>
nix run .\#secrets <hostname> <name> # <name>.yaml for <hostname>
```

[sops-nix]: https://github.com/Mic92/sops-nix


Operational notes
-----------------

### Backups

Backups are managed by `shared/backups` and uploaded to S3 with [Duplicity][].

Check the status of a backup collection with:

```bash
nix run .\#backups                   # for the current host
nix run .\#backups status            # for the current host
nix run .\#backups status <hostname> # for another host
```

Restore a backup to `/tmp/backup-restore` with:

```bash
nix run .\#backups restore            # for the current host
nix run .\#backups restore <hostname> # for another host
```

Change the restore target by setting `$RESTORE_DIR`.

[Duplicity]: https://duplicity.gitlab.io/

### ZFS

If there are any ZFS filesystems, the auto-trim, -scrub, and -snapshot jobs will
be enabled, as well as a Prometheus alert for if a pool becomes unhealthy (if
Alertmanager is enabled on this host).

Enable the auto-trim for a pool with:

```bash
sudo zpool set autotrim=on <pool>
```

Enable the auto-snapshot for a dataset with:

```bash
sudo zfs set com.sun:auto-snapshot=true <dataset>
```

The auto-scrub and the alert apply to all pools.
