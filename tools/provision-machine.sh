#!/usr/bin/env bash

set -e

# see https://nixfiles.docs.barrucadu.co.uk/runbooks/set-up-a-new-host.html

MODE="$1"
DEVICE="$2"

if ! [ "$(id -u)" -eq 0 ]; then
    echo "please run as root"
    exit 1
fi

if ! command -v git &>/dev/null; then
    echo "git not found in the PATH"
    exit 1
fi

if ! command -v nixos-generate-config &>/dev/null; then
    echo "nixos-generate-config not found in the PATH"
    exit 1
fi

if ! [ -e "$DEVICE" ]; then
    echo "${DEVICE} not found"
    exit 1
fi

# create partitions
case "$MODE" in
    "gpt")
        parted "$DEVICE" -- mklabel gpt
        parted "$DEVICE" -- mkpart ESP fat32 1MB 512MB
        parted "$DEVICE" -- mkpart root 512MB 100%
        parted "$DEVICE" -- set 1 esp on
        ;;
    "msdos")
        parted "$DEVICE" -- mklabel msdos
        parted "$DEVICE" -- mkpart primary 1MB 512MB
        parted "$DEVICE" -- mkpart primary 512MB 100%
        parted "$DEVICE" -- set 1 boot on
        ;;
    *)
        echo "${MODE} should be gpt or msdos"
        exit 1
        ;;
esac

BOOTDEV="${DEVICE}1"
ROOTDEV="${DEVICE}2"

# create /boot filesystem
mkfs.fat -F 32 -n boot "$BOOTDEV"

# create zfs datasets & snapshot for erase-your-darlings
zpool create -o autotrim=on local "$ROOTDEV"

zfs create -o mountpoint=legacy local/volatile
zfs create -o mountpoint=legacy local/volatile/root

zfs create -o mountpoint=legacy local/persistent
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/home
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/nix
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true local/persistent/persist
zfs create -o mountpoint=legacy -o com.sun:auto-snapshot=true -o xattr=sa -o acltype=posix local/persistent/var-log

zfs snapshot local/volatile/root@blank

# mount filesystems
mount -t zfs local/volatile/root /mnt

mkdir /mnt/boot
mkdir /mnt/home
mkdir /mnt/nix
mkdir /mnt/persist
mkdir -p /mnt/var/log

mount -t vfat "$BOOTDEV" /mnt/boot
mount -t zfs local/persistent/home /mnt/home
mount -t zfs local/persistent/nix /mnt/nix
mount -t zfs local/persistent/persist /mnt/persist
mount -t zfs local/persistent/var-log /mnt/var/log

# generate config
mkdir /mnt/persist/etc
pushd /mnt/persist/etc
git clone https://github.com/barrucadu/nixfiles.git nixos
popd

mkdir /mnt/persist/etc/nixos/hosts/new
cat <<EOF > /mnt/persist/etc/nixos/hosts/new/header.nix
# This is {...}.
#
# It runs {...}.
#
# **Alerting:** disabled
#
# **Backups:** disabled
#
# **Public hostname:** n/a
#
# **Role:** server
{ config, lib, pkgs, ... }:

with lib;
{
  networking.hostId = "$(head -c 4 /dev/urandom | xxd -p)";
  boot.supportedFilesystems = { zfs = true; };

  ###############################################################################
  ## GENERATED CONFIG BELOW THIS LINE
  ###############################################################################

EOF

nixos-generate-config --root /mnt
cat /mnt/persist/etc/nixos/hosts/new/header.nix /mnt/etc/nixos/configuration.nix > /mnt/persist/etc/nixos/hosts/new/configuration.nix
rm /mnt/persist/etc/nixos/hosts/new/header.nix
rm /mnt/etc/nixos/configuration.nix
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/persist/etc/nixos/hosts/new/hardware.nix
rmdir /mnt/etc/nixos

nano /mnt/persist/etc/nixos/hosts/new/configuration.nix
nano /mnt/persist/etc/nixos/hosts/new/hardware.nix

echo ""
echo "1. rename /mnt/persist/etc/nixos/hosts/new for new hostname"
echo "2. add to /mnt/persist/etc/nixos/flake.nix"
echo "3. add to git"
echo "4. run nixos-install --flake /mnt/persist/etc/nixos#hostname"
echo "5. reboot"
