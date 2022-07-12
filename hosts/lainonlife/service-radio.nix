# Radio stuff.
{ pkgs, lib, ... }:

with lib;
let
  # Configuration for the radio user.
  user = "radio";
  group = "audio";
  home = "/srv/radio";
  dataDirFor = channel: "${home}/data/${channel}";
  musicDirFor = channel: "${home}/music/${channel}";

  # A systemd service
  service = { environment ? { }, description, preStart ? null, startAt ? null, PermissionsStartOnly ? false, ExecStart, Type ? "simple", Restart ? "on-failure" }:
    mkMerge [
      {
        inherit environment description;
        after = [ "network.target" "sound.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          inherit ExecStart PermissionsStartOnly Type Restart;
          User = user;
          Group = group;
        };
      }
      (if preStart != null then { inherit preStart; } else { })
      (if startAt != null then { inherit startAt; } else { })
    ];

in
{
  # The radio runs as its own user, with music files stored in $HOME/music/$CHANNEL and state files
  # in $HOME/data/$CHANNEL.
  #
  # > users.extraUsers."${radio.username}" = radio.userSettings;
  username = user;

  userSettings = {
    inherit home group;
    isSystemUser = true;
    description = "Music Player Daemon user";
    shell = "${pkgs.bash}/bin/bash";
  };

  # MPD service settings.
  #
  # > systemd.services."mpd-random" = radio.mpdServiceFor channel_spec;
  mpdServiceFor = args@{ channel, mpdConfigFile, ... }: service {
    description = "Music Player Daemon (channel ${channel})";
    preStart = "mkdir -p ${dataDirFor channel} && chown -R ${user}:${group} ${dataDirFor channel}";
    PermissionsStartOnly = true;
    ExecStart = "${pkgs.mpd}/bin/mpd --no-daemon ${mpdConfigFile}";
  };

  # MP3 fallback service settings.
  #
  # > systemd.services."fallback-mp3" = radio.fallbackServiceForMP3 "/path/to/file.mp3" config.sops.secrets.foo.path;
  fallbackServiceForMP3 = path: fallbackConfigFile: service {
    description = "Fallback Stream (mp3)";
    ExecStart = "${pkgs.ezstream}/bin/ezstream -c ${fallbackConfigFile}";
  };

  # Ogg fallback service settings.
  #
  # > systemd.services."fallback-ogg" = radio.fallbackServiceForOgg "/path/to/file.ogg";
  fallbackServiceForOgg = path: service {
    description = "Fallback Stream (ogg)";
    ExecStart = "${pkgs.ezstream}/bin/ezstream -c ${fallbackConfigFile}";
  };

  # Programming service settings.
  #
  # > systemd.services."programme-random" = radio.programmingServiceFor channel_spec;
  programmingServiceFor = { channel, port, ... }:
    let
      penv = pkgs.python3.buildEnv.override {
        extraLibs = with pkgs.python3Packages; [ docopt mpd2 ];
      };
    in
    service {
      description = "Radio Programming (channel ${channel})";
      startAt = "0/3:00:00";
      ExecStart = "${pkgs.python3}/bin/python3 /srv/radio/scripts/schedule.py ${toString port}";
      Type = "oneshot";
      Restart = "no";
      environment = {
        PYTHONPATH = "${penv}/${pkgs.python3.sitePackages}/";
      };
    };
}
