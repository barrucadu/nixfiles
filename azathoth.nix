{ pkgs, ... }:

let
  nfsShare = name:
    { device = "nyarlathotep:/${name}"
    ; fsType = "nfs"
    ; options = [ "x-systemd.automount" "noauto" ]
    ; };
in

{
  networking.hostName = "azathoth";

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./base/default.nix

      # Include other configuration.
      ./common/kernel.nix
      ./services/mpd.nix
      ./services/openssh.nix
      ./services/syncthing.nix
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

  # Enable redshift
  services.redshift = {
    enable = true;
    # York
    latitude  = "53.953";
    longitude = "-1.0391";
  };

  # Nyarlathotep
  networking.interfaces.enp6s0.ipAddress = "10.1.1.2";
  networking.interfaces.enp6s0.prefixLength = 24;

  networking.extraHosts = "10.1.1.1 nyarlathotep";

  fileSystems."/home/barrucadu/nfs/anime"    = nfsShare "anime";
  fileSystems."/home/barrucadu/nfs/music"    = nfsShare "music";
  fileSystems."/home/barrucadu/nfs/movies"   = nfsShare "movies";
  fileSystems."/home/barrucadu/nfs/tv"       = nfsShare "tv";
  fileSystems."/home/barrucadu/nfs/images"   = nfsShare "images";
  fileSystems."/home/barrucadu/nfs/torrents" = nfsShare "torrents";

  # Postgres
  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql95;

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
      { inherit (texlive) scheme-medium; })
  ];
}
