Move a configuration to a new machine
=====================================

Follow the [set up a new host](./set-up-a-new-host.md) instructions up to
**step 5** (cloning the nixfiles repo to `/etc/nixos`).

Then:

1. Merge the generated machine configuration into the nixfiles configuration
1. Copy the sops master key to `.config/sops/age/keys.txt`
1. **If using secrets:** Re-encrypt the secrets
1. **If there is a backup:** Restore the latest backup
1. Remove the sops master key
1. **If wiping / on boot:** Copy any files which need to be preserved to the appropriate place in `/persist`
1. **Optional:** Update DNS records
1. **Optional:** Generate SSH key
1. Build the new system configuration with `sudo nixos-rebuild switch --flake '.#<hostname>'`
1. Reboot
1. Commit, push, & merge
1. **Optional:** Configure Syncthing


If using secrets: Re-encrypt the secrets
----------------------------------------

After first boot, generate an age public key from the host SSH key:

```bash
nix-shell -p ssh-to-age --run 'ssh-keyscan localhost | ssh-to-age'
```

Replace the old key in `.sops.yaml` with the new key:

```yaml
creation_rules:
  ...
  - path_regex: hosts/<hostname>/secrets(/[^/]+)?\.yaml$
    key_groups:
      - age:
          - *barrucadu
          - '<old-key>' # delete
          - '<new-key>' # insert
```

Update the host's encryption key:

```bash
nix shell "nixpkgs#sops" -c sops updatekeys hosts/<hostname>/secrets.yaml
```


If there is a backup: Restore the latest backup
-----------------------------------------------

Download the latest backup to `/tmp/backup-restore`:

```bash
nix run .#backups restore <hostname>
```

Then move files to restore to the appropriate locations.


Optional: Update DNS records
----------------------------

If there are any DNS records referring to the old machine which are now
incorrect (e.g. due to an IP address change), make the needed changes to [the
ops repo][] and apply the change via [Concourse][].

[the ops repo]: https://github.com/barrucadu/ops
[Concourse]: https://cd.barrucadu.dev/


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

Remove the old SSH key for this host from anywhere it's used.


Optional: Configure Syncthing
-----------------------------

Use the Syncthing Web UI (`localhost:8384`) to get the machine's ID.  Replace
the old machine's ID and folder sharing permissions with the new machine, for
any other machines which synchronised files with it.
