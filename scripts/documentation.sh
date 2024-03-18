set -e

pushd docs
mdbook-admonish install
popd

sed 's#See \[the documentation\].*##' < README.markdown > docs/src/README.md

python3 - <<'EOF' > docs/src/hosts.md
import os

print("# Hosts")
print("")

hosts = sorted([name for name in os.listdir("hosts") if name not in [".", ".."]])
for host in hosts:
    source_file = f"hosts/{host}/configuration.nix"

    print(f"## {host}")

    has_doc = False
    with open(source_file, "r") as f:
        for line in f:
            if line.startswith("#"):
                has_doc = True
                print(line[1:].strip())
            else:
                break
    if not has_doc:
        print("This host has no description.")
    print(f"\n**Declared in:** [{source_file}](https://github.com/barrucadu/nixfiles/blob/master/{source_file})")
    print("")
EOF

python3 - <<'EOF' > docs/src/modules.md
import json
import os

print("# Modules")
print("")

with open(os.getenv("NIXOS_OPTIONS_JSON"), "r") as f:
    options = json.load(f)
    del options["_module.args"]

modules = {}
for key, defn in options.items():
    module_name = defn["declarations"][0].split("/shared/")[1].replace("/options.nix", "")
    if module_name == "options.nix":
        # this is the top-level `shared` file
        module_name = ""
    modules.setdefault(module_name, []).append(key)

for module in sorted(modules.keys()):
    module_name = "&lt;shared&gt;" if module == "" else module
    source_file = f"shared/{module}/default.nix".replace("//", "/")

    print(f"## {module_name}")

    has_doc = False
    with open(source_file, "r") as f:
        for line in f:
            if line.startswith("#"):
                has_doc = True
                print(line[1:].strip())
            else:
                break
    if not has_doc:
        print("This module has no description.")

    print("\n**Options:**\n")
    for option in modules[module]:
        anchor = "".join(c for c in option if c.isalpha() or c in "-_").lower()
        print(f"- [`{option}`](./options.md#{anchor})")
    print(f"\n**Declared in:** [{source_file}](https://github.com/barrucadu/nixfiles/blob/master/{source_file})")
    print("")
EOF

python3 - <<'EOF' > docs/src/options.md
import json
import os

print("# Options")
print("")

with open(os.getenv("NIXOS_OPTIONS_JSON"), "r") as f:
    options = json.load(f)
    del options["_module.args"]

for option in sorted(options.keys()):
    defn = options[option]
    option_name = option.replace("*", "\\*").replace("<", "&lt;").replace(">", "&gt;")
    source_file = "shared/" + defn["declarations"][0].split("/shared/")[1]

    print(f"## {option_name}")
    if isinstance(defn["description"], str):
        print(f"\n{defn['description']}")
    else:
        print(f"\n{defn['description']['text']}")
    print(f"\n**Type:** `{defn['type']}`")
    if "default" in defn:
        print(f"\n**Default:** `{defn['default']['text']}`")
    if "example" in defn:
        print(f"\n**Example:** `{defn['example']['text']}`")
    print(f"\n**Declared in:** [{source_file}](https://github.com/barrucadu/nixfiles/blob/master/{source_file})")
    print("")
EOF

mdbook build docs
mv docs/book _site

chmod -c -R +rX _site | while read -r line; do
    echo "::warning title=Invalid file permissions automatically fixed::$line"
done
