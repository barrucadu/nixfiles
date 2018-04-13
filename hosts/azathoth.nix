{ pkgs, ... }:

let
  nfsShare = name:
    { device = "nyarlathotep.dot:/${name}"
    ; fsType = "nfs"
    ; options = [ "x-systemd.automount" "noauto" ]
    ; };
in

{
  networking.hostName = "azathoth";

  imports = [
    ./common.nix
    ./hardware-configuration.nix
    ./services/mpd.nix
    ./services/xserver.nix
  ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Windows
  fileSystems."/mnt/data".device = "/dev/disk/by-label/Data";
  fileSystems."/mnt/data".fsType = "ntfs";

  boot.loader.grub.extraEntries = ''
    menuentry "Windows 10" {
      set root=(hd1,1)
      chainloader +1
    }
  '';

  # Enable nvidia graphics
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.driSupport32Bit = true;

  # Enable pulseaudio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Enable wifi
  networking.wireless.enable = true;

  # Nyarlathotep
  fileSystems."/home/barrucadu/nfs/anime"    = nfsShare "anime";
  fileSystems."/home/barrucadu/nfs/manga"    = nfsShare "manga";
  fileSystems."/home/barrucadu/nfs/music"    = nfsShare "music";
  fileSystems."/home/barrucadu/nfs/movies"   = nfsShare "movies";
  fileSystems."/home/barrucadu/nfs/tv"       = nfsShare "tv";
  fileSystems."/home/barrucadu/nfs/images"   = nfsShare "images";
  fileSystems."/home/barrucadu/nfs/torrents" = nfsShare "torrents";

  # Virtualisation
  virtualisation.virtualbox.host.enable = true;

  # Extra packages
  environment.systemPackages = with pkgs; [
    abcde
    gphoto2
    keybase
    libreoffice
    optipng
    (texlive.combine
      { inherit (texlive) scheme-full; })
  ];
}
