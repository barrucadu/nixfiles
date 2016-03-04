{config, ...}:

let
  cfg = config.services.openssh;
in
{
  services.openssh = {
    enable = true;

    # Only pubkey auth
    passwordAuthentication = false;
    challengeResponseAuthentication = false;
  };
}