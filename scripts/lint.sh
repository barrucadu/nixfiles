set -ex

# TODO: add this back when the package is no longer broken
# nix-linter -r .

# SC2001: use pattern expansion over sed
find . -name '*.sh' -print0 | xargs -0 -n1 shellcheck -s bash -e SC2001

# E501: line length (if black is happy, I'm happy)
# E731: assign lambda to a variable
find . -name '*.py' -print0 | xargs -0 -n1 flake8 --ignore=E501,E731

find . -name options.nix -print0 | while IFS= read -r -d '' filename; do
    if ! grep -q "$filename" flake.nix; then
        exit 1
    fi
done

if git grep 'options.nixfiles' | grep -vE 'options.nix'; then
    exit 1
fi

if git grep 'callPackage' | grep -vE 'flake.nix'; then
    exit 1
fi

if git grep 'OnCalendar' | grep -vE 'scripts/lint.sh'; then
    exit 1
fi

if git grep 'users.extraUsers' | grep -vE 'scripts/lint.sh'; then
    exit 1
fi

if git grep 'virtualisation.oci-containers' | grep -vE 'scripts/lint.sh|shared/oci-containers/'; then
    exit 1
fi
