set -ex

nix-linter -r .

# SC2001: use pattern expansion over sed
find . -name '*.sh' -print0 | xargs -0 -n1 shellcheck -s bash -e SC2001
