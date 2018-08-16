{ config, pkgs, ... }:

{ systemd.services.rtorrent =
  { enable   = true
  ; wantedBy = [ "default.target" ]
  ; after    = [ "network.target" ]
  ; serviceConfig =
    { ExecStart = "${pkgs.tmux}/bin/tmux new-session -d -s rtorrent '${pkgs.rtorrent}/bin/rtorrent'"
    ; ExecStop  = "${pkgs.tmux}/bin/tmux send-keys -t rtorrent C-q"
    ; User      = "barrucadu"
    ; KillMode  = "none"
    ; Type      = "forking"
    ; Restart   = "on-failure"
    ; WorkingDirectory = "%h"
    ; }
  ; }

; environment.systemPackages = with pkgs;
  [ mktorrent
    rtorrent
    tmux
  ]
; }
