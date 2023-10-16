Set up a new host
=================

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
1. **Optional:** Configure alerting
1. **Optional:** Configure backups
1. **Optional:** Generate SSH key
1. Build the new system configuration with `sudo nixos-rebuild switch --flake '.#<hostname>'`
1. Reboot
1. Commit, push, & merge


Optional: Configure wiping / on boot
------------------------------------

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


Optional: Add DNS records
-------------------------

Add `A` / `AAAA` records to [the ops repo][] and apply the change via
[Concourse][].

[the ops repo]: https://github.com/barrucadu/ops
[Concourse]: https://cd.barrucadu.dev/


Optional: Configure secrets
---------------------------

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


Optional: Configure alerting
----------------------------

All hosts have [Alertmanager][] installed and enabled.  To actually publish
alerts, create a secret for the environment file with credentials for the
`host-notifications` SNS topic:

```text
AWS_ACCESS_KEY="..."
AWS_SECRET_ACCESS_KEY="..."
```

Then configure the environment file:

```nix
services.prometheus.alertmanager.environmentFile = config.sops.secrets."services/alertmanager/env".path;
sops.secrets."services/alertmanager/env" = { };
```

[Alertmanager]: https://prometheus.io/docs/alerting/latest/alertmanager/


Optional: Configure backups
---------------------------

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


Optional: Generate SSH key
--------------------------

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
