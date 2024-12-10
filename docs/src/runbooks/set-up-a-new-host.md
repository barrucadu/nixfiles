Set up a new host
=================

```admonish info
See also [the NixOS installation instructions](https://nixos.org/manual/nixos/stable/index.html#ch-installation).
```

Install NixOS
-------------

Boot into the ISO and install NixOS with `tools/provision-machine.sh`:

```bash
sudo -i
nix-env -f '<nixpkgs>' -iA git
curl https://raw.githubusercontent.com/barrucadu/nixfiles/master/tools/provision-machine.sh > provision-machine.sh
bash provision-machine.sh gpt /dev/sda
```

Then:

1. Rename `/mnt/persist/etc/nixos/hosts/new` after the new hostname
2. Add the host to `/mnt/persist/etc/nixos/flake.nix`
3. Add the new files to git
4. Run `nixos-install --flake /mnt/persist/etc/nixos#hostname`
5. Reboot


First boot
----------

Generate an age public key from the host SSH key:

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan localhost | ssh-to-age'
```

Add a new section with this key to `/persist/etc/nixos/.sops.yaml`:

```yaml
creation_rules:
  ...
  - path_regex: hosts/<hostname>/secrets(/[^/]+)?\.yaml$
    key_groups:
      - age:
          - *barrucadu
          - '<key>'
```

Add a `users/barrucadu` secret with the hashed user password:

```bash
nix run .#secrets
```

Copy the host SSH keys to `/etc/persist`:

```bash
sudo mkdir /persist/etc/ssh
sudo cp /etc/ssh/ssh_host_rsa_key /persist/etc/ssh/ssh_host_rsa_key
sudo cp /etc/ssh/ssh_host_ed25519_key /persist/etc/ssh/ssh_host_ed25519_key
```

Enable `nixfiles.eraseYourDarlings`:

```nix
nixfiles.eraseYourDarlings.enable = true;
nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
sops.secrets."users/barrucadu".neededForUsers = true;
```

Make the `/persist` volume available in early boot:

```nix
fileSystems."/persist" =
  {
    device = "local/persistent/persist";
    fsType = "zfs";
    neededForBoot = true;
  };
```

Then:

1. Rebuild the system: `sudo nixos-rebuild boot --flake /persist/etc/nixos`
2. Reboot


Optional: Add DNS records
-------------------------

Add `A` / `AAAA` records to [the ops repo][] and apply the change via
[Concourse][].

[the ops repo]: https://github.com/barrucadu/ops
[Concourse]: https://cd.barrucadu.dev/


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
nixfiles.restic-backups.enable = true;
nixfiles.restic-backups.environmentFile = config.sops.secrets."nixfiles/restic-backups/env".path;
sops.secrets."nixfiles/restic-backups/env" = { };
```

Most services define their own backup scripts.  For any other needs, write a
custom backup job:

```nix
nixfiles.restic-backups.backups.<name> = { ... };
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


Optional: Configure Syncthing
-----------------------------

Use the Syncthing Web UI (`localhost:8384`) to get the machine's ID.  Add this
ID to any other machines which it should synchronise files with, through their
web UIs.

Then configure any shared folders.

