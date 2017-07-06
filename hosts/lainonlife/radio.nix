# Radio stuff.
{ pkgs, lib, ... }:

with lib;

let
  # Configuration for the radio user.
  user  = "radio";
  group = "audio";
  homeDir = "/srv/radio";
  dataDirFor  = channel: "${homeDir}/data/${channel}";
  musicDirFor = channel: "${homeDir}/music/${channel}";

  # Configuration for the Icecast server.
  icecastAdminPassword  = import /etc/nixos/secrets/icecast-admin-password.nix;
  icecastSourcePassword = import /etc/nixos/secrets/icecast-source-password.nix;

  # Configuration for an MPD instance.
  mpdConfigFor = { channel, description, port, password ? icecastSourcePassword, ... }:
    let shoutConfig = encoder: ext: ''
      audio_output {
        name        "[mpd] ${channel} (${ext})"
        description "${description}"
        type        "shout"
        encoder     "${encoder}"
        host        "localhost"
        port        "8000"
        mount       "/mpd-${channel}.${ext}"
        user        "source"
        password    "${password}"
        quality     "3"
        format      "44100:16:2"
        always_on   "yes"
      }
      '';
    in pkgs.writeText "mpd-${channel}.conf" ''
      music_directory     "${musicDirFor channel}"
      playlist_directory  "${dataDirFor channel}/playlists"
      db_file             "${dataDirFor channel}/db"
      state_file          "${dataDirFor channel}/state"
      sticker_file        "${dataDirFor channel}/sticker.sql"
      log_file            "syslog"
      bind_to_address     "127.0.0.1"
      port                "${toString port}"

      ${shoutConfig "vorbis" "ogg"}
      ${shoutConfig "lame"   "mp3"}

      audio_output {
        type "null"
        name "null"
      }
    '';
in

{
  # The radio runs as its own user, with music files stored in $HOME/music/$CHANNEL and state files
  # in $HOME/data/$CHANNEL.
  #
  # > users.extraUsers."${radio.username}" = radio.userSettings;
  username = user;

  userSettings = {
    isSystemUser = true;
    extraGroups = [ group ];
    description = "Music Player Daemon user";
    home = homeDir;
    shell = "${pkgs.bash}/bin/bash";
  };

  # Icecast service settings.
  #
  # > services.icecast = radio.icecastSettings [ { channel = "random"; description = "Anything and everything!"; password = "password"; } ... ];
  icecastSettingsFor = channels: {
    enable = true;
    hostname = "lainon.life";
    admin.password = icecastAdminPassword;
    extraConf =
      let channelMount = { channel, description, password ? icecastSourcePassword, ... }:
        let channelMountForExt = ext: ''
            <mount>
              <mount-name>/${channel}.${ext}</mount-name>
              <password>${password}</password>
              <fallback-mount>/mpd-${channel}.${ext}</fallback-mount>
              <fallback-override>1</fallback-override>
              <stream-name>${channel} (${ext}</stream-name>
              <stream-description>${description}</stream-description>
              <public>1</public>
            </mount>
            <mount>
              <mount-name>/mpd-${channel}.${ext}</mount-name>
              <password>${password}</password>
              <stream-name>[mpd] ${channel} (${ext})</stream-name>
              <stream-description>${description}</stream-description>
              <public>0</public>
            </mount>
          '';
        in channelMountForExt "mp3" + channelMountForExt "ogg";
      in concatMapStringsSep "\n" channelMount channels;
  };

  # MPD service settings.
  #
  # > systemd.services."mpd-random" = radio.mpdServiceFor { channel = "random"; port = 6600; description = "Anything and everything!"; password = "password"; };
  mpdServiceFor = args@{ channel, description, port, password, ... }: {
    after = [ "network.target" "sound.target" ];
    description = "Music Player Daemon (channel ${channel})";
    wantedBy = [ "multi-user.target" ];

    preStart = "mkdir -p ${dataDirFor channel} && chown -R ${user}:${group} ${dataDirFor channel}";
    serviceConfig = {
      User = user;
      Group = group;
      PermissionsStartOnly = true;
      ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon ${mpdConfigFor args}";
      Restart = "on-failure";
    };
  };

  # Programming service settings.
  #
  # > systemd.services."programme-random" = radio.programmingServiceFor { channel = "random"; port = 6600; };
  programmingServiceFor = {channel, port, ...}: {
    after = [ "network.target" "sound.target" ];
    description = "Radio Programming (channel ${channel})";
    wantedBy = [ "multi-user.target" ];
    startAt = "0/3:00:00";

    serviceConfig = {
      User = user;
      Group = group;
      ExecStart = "${pkgs.python3}/bin/python3 /srv/radio/scripts/schedule.py ${toString port}";
      Type = "oneshot";
    };
  };
}
