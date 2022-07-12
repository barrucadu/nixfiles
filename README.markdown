nixfiles
========

My [NixOS][] configuration and assorted other crap, powered by
[flakes][].  Clone to `/etc/nixos`.

See [the memo][] for machine-specific notes.

[NixOS]: https://nixos.org
[flakes]: https://nixos.wiki/wiki/Flakes
[the memo]: https://memo.barrucadu.co.uk/machines.html

Secrets
-------

Secrets are managed with [sops-nix][].  Create / edit secrets with:

```
./sops.sh                   # secrets.yaml for current host
./sops.sh <hostname>        # secrets.yaml for <hostname>
./sops.sh <hostname> <name> # <name>.yaml for <hostname>
```

[sops-nix]: https://github.com/Mic92/sops-nix
