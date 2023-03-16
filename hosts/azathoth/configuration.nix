{ pkgs, ... }:
let
  nfsShare = name:
    {
      device = "nyarlathotep:/${name}";
      fsType = "nfs";
      options = [ "x-systemd.automount" "noauto" ];
    };
in
{
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

  # Nyarlathotep
  fileSystems."/home/barrucadu/nfs/anime" = nfsShare "anime";
  fileSystems."/home/barrucadu/nfs/manga" = nfsShare "manga";
  fileSystems."/home/barrucadu/nfs/misc" = nfsShare "misc";
  fileSystems."/home/barrucadu/nfs/music" = nfsShare "music";
  fileSystems."/home/barrucadu/nfs/movies" = nfsShare "movies";
  fileSystems."/home/barrucadu/nfs/tv" = nfsShare "tv";
  fileSystems."/home/barrucadu/nfs/images" = nfsShare "images";
  fileSystems."/home/barrucadu/nfs/torrents" = nfsShare "torrents";

  # Enable Xorg, to auto-login to herbstluftwm, with C-M-Bksp enabled.
  services.xserver = {
    enable = true;
    enableCtrlAltBackspace = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "barrucadu";
    windowManager.herbstluftwm.enable = true;
  };

  # Sane font defaults
  fonts = {
    fontDir.enable = true;
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
  users.extraUsers.barrucadu.packages = with pkgs; [
    chromium
    clementine
    discord
    emacs
    evince
    feh
    firefox
    gimp
    gmrun
    keepassxc
    mpv
    scrot
    xclip
    (texlive.combine { inherit (texlive) scheme-full; })
  ];

  environment.systemPackages = with pkgs; [
    rxvt_unicode
    rxvt_unicode.terminfo
  ];
}
