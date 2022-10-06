set -ex

nix-linter -r .

shellcheck -s bash scripts/*
