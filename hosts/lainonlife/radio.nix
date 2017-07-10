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
  icecastAdminPassword    = import /etc/nixos/secrets/icecast-admin-password.nix;
  icecastFallbackPassword = import /etc/nixos/secrets/icecast-fallback-password.nix;
  fallbackMP3Mount = "fallback.mp3";
  fallbackOggMount = "fallback.ogg";

  # Configuration for an MPD instance.
  mpdConfigFor = { channel, description, port, mpdPassword, ... }:
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
        password    "${mpdPassword}"
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

  # Configuration for an Ezstream fallback instance.
  fallbackConfigFor = file: format: mount:
    pkgs.writeText "ezstream-${format}.conf" ''
      <ezstream>
        <url>http://127.0.0.1:8000/${mount}</url>
        <sourcepassword>${icecastFallbackPassword}</sourcepassword>
        <format>${format}</format>
        <filename>${file}</filename>
      </ezstream>
    '';

  # A systemd service
  service = {description, preStart ? null, startAt ? null, PermissionsStartOnly ? false, ExecStart, Type ? "simple", Restart ? "on-failure" }:
    mkMerge [
      { inherit description;
        after    = [ "network.target" "sound.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          inherit ExecStart PermissionsStartOnly Type Restart;
          User  = user;
          Group = group;
        };
      }
      (if preStart != null then { inherit preStart; } else { })
      (if startAt  != null then { inherit startAt;  } else { })
    ];

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
  # > services.icecast = radio.icecastSettings [ channel_spec ];
  icecastSettingsFor = channels: {
    enable = true;
    hostname = "lainon.life";
    admin.password = icecastAdminPassword;
    extraConf =
      let
        channelMount = { channel, description, mpdPassword, livePassword, ... }:
          let mount = ismpd: ext: ''
              <mount>
                <mount-name>/${if ismpd then "mpd-${channel}" else channel}.${ext}</mount-name>
                <password>${if ismpd then mpdPassword else livePassword}</password>
                <fallback-mount>/${if ismpd then "fallback" else "mpd-${channel}"}.${ext}</fallback-mount>
                <fallback-override>1</fallback-override>
                <stream-name>${channel} (${ext})</stream-name>
                <stream-description>${description}</stream-description>
                <public>${if ismpd then "0" else "1"}</public>
              </mount>
            '';
          in mount false "mp3" + mount true "mp3" + mount false "ogg" + mount true "ogg";

        fallbackMount = ext: ''
          <mount>
            <mount-name>/fallback.${ext}</mount-name>
            <password>${icecastFallbackPassword}</password>
            <stream-name>Fallback Stream (${ext})</stream-name>
            <stream-description>you should never hear this</stream-description>
            <public>0</public>
          </mount>
        '';
      in concatMapStringsSep "\n" channelMount channels + fallbackMount "mp3" + fallbackMount "ogg";
  };

  # MPD service settings.
  #
  # > systemd.services."mpd-random" = radio.mpdServiceFor channel_spec;
  mpdServiceFor = args@{ channel, ... }: service {
    description = "Music Player Daemon (channel ${channel})";
    preStart = "mkdir -p ${dataDirFor channel} && chown -R ${user}:${group} ${dataDirFor channel}";
    PermissionsStartOnly = true;
    ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon ${mpdConfigFor args}";
  };

  # MP3 fallback service settings.
  #
  # > systemd.services."fallback-mp3" = radio.fallbackServiceForMP3 "/path/to/file.mp3";
  fallbackServiceForMP3 = path: service {
    description = "Fallback Stream (mp3)";
    ExecStart = "${pkgs.ezstream}/bin/ezstream -c ${fallbackConfigFor path "MP3" fallbackMP3Mount}";
  };

  # Ogg fallback service settings.
  #
  # > systemd.services."fallback-ogg" = radio.fallbackServiceForOgg "/path/to/file.ogg";
  fallbackServiceForOgg = path: service {
    description = "Fallback Stream (ogg)";
    ExecStart = "${pkgs.ezstream}/bin/ezstream -c ${fallbackConfigFor path "Vorbis" fallbackOggMount}";
  };

  # Programming service settings.
  #
  # > systemd.services."programme-random" = radio.programmingServiceFor channel_spec;
  programmingServiceFor = {channel, port, ...}: service {
    description = "Radio Programming (channel ${channel})";
    startAt = "0/3:00:00";
    ExecStart = "${pkgs.python3}/bin/python3 /srv/radio/scripts/schedule.py ${toString port}";
    Type = "oneshot";
    Restart = "no";
  };
}
