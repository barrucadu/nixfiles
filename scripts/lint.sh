set -ex

nix-linter -r .

# SC2001: use pattern expansion over sed
find . -name '*.sh' -print0 | xargs -0 -n1 shellcheck -s bash -e SC2001

if git grep 'virtualisation.oci-containers' | grep -vE 'scripts/lint.sh|shared/oci-containers/'; then
    exit 1
fi
