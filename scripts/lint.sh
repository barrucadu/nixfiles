set -ex

nix-linter -r .

# SC2001: use pattern expansion over sed
find . -name '*.sh' -print0 | xargs -0 -n1 shellcheck -s bash -e SC2001

# E501: line length (if black is happy, I'm happy)
# E731: assign lambda to a variable
find . -name '*.py' -print0 | xargs -0 -n1 flake8 --ignore=E501,E731

if git grep 'callPackage' | grep -vE 'flake.nix'; then
    exit 1
fi

if git grep 'virtualisation.oci-containers' | grep -vE 'scripts/lint.sh|shared/oci-containers/'; then
    exit 1
fi
