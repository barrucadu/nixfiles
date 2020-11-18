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

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable memtest
  boot.loader.systemd-boot.memtest86.enable = true;

  # Enable nvidia graphics
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl.driSupport32Bit = true;

  # Enable pulseaudio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "enp6s0" ];

  # Nyarlathotep
  fileSystems."/home/barrucadu/nfs/anime"    = nfsShare "anime";
  fileSystems."/home/barrucadu/nfs/manga"    = nfsShare "manga";
  fileSystems."/home/barrucadu/nfs/misc"     = nfsShare "misc";
  fileSystems."/home/barrucadu/nfs/music"    = nfsShare "music";
  fileSystems."/home/barrucadu/nfs/movies"   = nfsShare "movies";
  fileSystems."/home/barrucadu/nfs/tv"       = nfsShare "tv";
  fileSystems."/home/barrucadu/nfs/images"   = nfsShare "images";
  fileSystems."/home/barrucadu/nfs/torrents" = nfsShare "torrents";

  # Enable xorg
  services.xserver.enable = true;

  # Set the default x session to herbstluftwm
  services.xserver.windowManager.herbstluftwm.enable = true;

  # Enable C-M-Bksp to kill X
  services.xserver.enableCtrlAltBackspace = true;

  # Use lightdm instead of slim
  services.xserver.displayManager.lightdm.enable = true;

  # Sane font defaults
  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fontconfig.cache32Bit = true;

    fonts = with pkgs; [
      terminus_font
      source-code-pro
    ];
  };

  # Start the urxvtd user service
  services.urxvtd.enable = true;

  # Extra packages
  environment.systemPackages = with pkgs; [
    clementine
    discord
    feh
    haskellPackages.hledger
    gnuplot
    lightdm
    python3Packages.pygments
    (texlive.combine { inherit (texlive) scheme-full; })
  ];
}
