#!/usr/bin/env nix-shell
#!nix-shell -i bash -p sops

if [[ -z "$1" ]]; then
  SECRETS_FILE="hosts/$(hostname)/secrets.yaml"
elif [[ -z "$2" ]]; then
  SECRETS_FILE="hosts/${1}/secrets.yaml"
else
  SECRETS_FILE="hosts/${1}/secrets/${2}.yaml"
fi

sops "$SECRETS_FILE"
