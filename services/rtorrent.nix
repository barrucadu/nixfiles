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

; systemd.services.flood =
  { enable   = true
  ; wantedBy = [ "default.target" ]
  ; after    = [ "network.target" ]
  ; serviceConfig =
    { ExecStart = "${pkgs.zsh}/bin/zsh --login -c '${pkgs.nodejs-8_x}/bin/npm start'"
    ; User      = "barrucadu"
    ; KillMode  = "none"
    ; Restart   = "on-failure"
    ; WorkingDirectory = "/home/barrucadu/flood"
    ; }
  ; }

; environment.systemPackages = with pkgs;
  [ mktorrent
    nodejs-8_x
    rtorrent
    tmux
  ]
; }
