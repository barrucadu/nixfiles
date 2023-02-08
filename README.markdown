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

Currently I have 4 NixOS machines.  The naming convention is:

- **Local machines:** beings (gods, people, etc) of the Cthulhu Mythos.
- **Remote machines:** places of the Cthulhu Mythos.

#### azathoth

This is my desktop computer.

It dual-boots Windows and NixOS, so it doesn’t run any services, as they won't
be accessible half of the time.  I don't bother backing up either OS: everything
I care about is in Syncthing, on GitHub, or on some other cloud service (eg,
Steam).

#### carcosa

This is a VPS (hosted by Hetzner Cloud).

It serves [barrucadu.co.uk][] and other services on it, such as [a bookdb
instance][] and [my blog][].  Websites are served with Caddy, with certs from
Let's Encrypt.

It's set up in "erase your darlings" style, so most of the filesystem is wiped
on boot and restored from the configuration, to ensure there's no accidentally
unmanaged configuration or state hanging around.  However, it doesn't reboot
automatically, because I also use this server for a persistent IRC connection.

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

It runs writable instances of the bookdb and bookmarks services, which have any
updates copied across to carcosa hourly; it acts as a NAS; and it runs a few
utility services, such as a dashboard of finance information from my hledger
journal, and a script to automatically tag and organise new podcast episodes or
CD rips which I copy over to it.

Like carcosa, this host is set up in "erase your darlings" style but, unlike
carcosa, it automatically reboots to install updates: so that takes effect
significantly more frequently.


Setting up a new host
---------------------

See also [the NixOS installation instructions](https://nixos.org/manual/nixos/stable/index.html#ch-installation).

1. Create & format partitions
1. **Optional:** Configure wiping / on boot (pre-first-boot steps)
1. Install NixOS with the standard installer
1. Reboot into the installed system
1. Clone this repo to `/etc/nixos`
1. Move the generated configuration to `hosts/<hostname>/` and edit to fit repo conventions
1. Add an entry for the host to `flake.nix`
1. **Optional:** Add DNS records
1. **Optional:** Configure secrets
1. **Optional:** Configure wiping / on boot (post-first-boot steps)
1. **Optional:** Configure backups
1. **Optional:** Generate SSH key
1. Build the new system configuration with `sudo nixos-rebuild switch --flake '.#<hostname>'`
1. Reboot
1. Commit, push, & merge

### Optional: Configure wiping / on boot

Before installing NixOS, create the `local` pool and datasets:

```bash
zpool create -o mountpoint=legacy -o autotrim=on local <device>

zfs create -o mountpoint=legacy local/volatile
zfs create -o mountpoint=legacy local/volatile/root

zfs create -o mountpoint=legacy local/persistent
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/home
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/nix
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/persist
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/var-log
```

Take a snapshot of the empty root dataset:

```bash
zfs snapshot local/volatile/root@blank
```

Mount all the filesystems under `/mnt`:

```bash
mount -t zfs local/volatile/root /mnt

mkdir /mnt/boot
mkdir /mnt/home
mkdir /mnt/nix
mkdir /mnt/persist
mkdir -p /mnt/var/log

mount /dev/<boot device> /mnt/boot
mount -t zfs local/persistent/home /mnt/home
mount -t zfs local/persistent/nix /mnt/nix
mount -t zfs local/persistent/persist /mnt/persist
mount -t zfs local/persistent/var-log /mnt/var/log
```

Then run the installer, making sure to add ZFS details to the generated configuration:

```nix
networking.hostId = "<random 32-bit hex value>";
boot.supportedFilesystems = [ "zfs" ];
```

**After first boot:** copy any needed files (eg, SSH host keys) to the
appropriate place in `/persist`, add the user password to the secrets, and set
up `nixfiles.eraseYourDarlings`:

```nix
nixfiles.eraseYourDarlings.enable = true;
nixfiles.eraseYourDarlings.machineId = "<contents of /etc/machine-id>";
nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
sops.secrets."users/barrucadu".neededForUsers = true;
```

### Optional: Add DNS records

Add `A` / `AAAA` records to [the ops repo](https://github.com/barrucadu/ops) and
apply the change via [Concourse](https://cd.barrucadu.dev/).

### Optional: Configure secrets

After first boot, generate an age public key from the host SSH key:

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan <hostname>.barrucadu.co.uk | ssh-to-age'
```

Add a new section with this key to `.sops.yaml`:

```yaml
creation_rules:
  ...
  - path_regex: hosts/<hostname>/secrets(/[^/]+)?\.yaml$
    key_groups:
      - age:
          - *barrucadu
          - '<key>'
```

Enable sops in the host configuration:

```nix
sops.defaultSopsFile = ./secrets.yaml;
```

### Optional: Configure backups

All hosts which run any sort of service with data I care about should take
automatic backups.

Firstly, add the backup credentials to the secrets:

```bash
nix run .#secrets
```

Then enable backups in the host configuration:

```nix
nixfiles.backups.enable = true;
nixfiles.backups.environmentFile = config.sops.secrets."nixfiles/backups/env".path;
sops.secrets."nixfiles/backups/env" = { };
```

Most services define their own backup scripts.  For any other needs, write a
custom script:

```nix
nixfiles.backups.scripts.<name> = ''
  <script which copies files to backup to the current working directory>
'';
```

### Optional: Generate SSH key

Generate an ed25519 SSH key:

```bash
ssh-keygen -t ed25519
```

**If the host should be able to interact with GitHub:** add the public key to
the GitHub user configuration *as an SSH key*.

**If the host should be able to push commits to GitHub:** add
the public key to the GitHub user configuration *as a signing key*, and also add
it to [the allowed_signers
file](https://github.com/barrucadu/dotfiles/blob/master/dot_config/git/allowed_signers.tmpl).

**If the host should be able to connect to other machines:** add the public key
to `shared/default.nix`.


Tools
-----

### Backups

Backups are managed by `shared/backups` and uploaded to S3 with [Duplicity][].

Check the status of a backup collection with:

```bash
nix run .#backups                   # for the current host
nix run .#backups status            # for the current host
nix run .#backups status <hostname> # for another host
```

Restore a backup to `/tmp/backup-restore` with:

```bash
nix run .#backups restore            # for the current host
nix run .#backups restore <hostname> # for another host
```

Change the restore target by setting `$RESTORE_DIR`.

[Duplicity]: https://duplicity.gitlab.io/

### Secrets

Secrets are managed with [sops-nix][].  Create / edit secrets with:

```bash
nix run .#secrets                   # secrets.yaml for current host
nix run .#secrets <hostname>        # secrets.yaml for <hostname>
nix run .#secrets <hostname> <name> # <name>.yaml for <hostname>
```

[sops-nix]: https://github.com/Mic92/sops-nix
