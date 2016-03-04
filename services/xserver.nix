{ config, pkgs, ... }:

{
  services.xserver.enable = true;

  # Set the default x session to herbstluftwm
  services.xserver.windowManager.herbstluftwm.enable = true;

  # Enable C-M-Bksp to kill X
  services.xserver.enableCtrlAltBackspace = true;
}