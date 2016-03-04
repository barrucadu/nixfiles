{ config, lib, ... }:

with lib;

{
  # Use zsh as the default shell.
  programs.zsh.enable = true;
  users.defaultUserShell = "/run/current-system/sw/bin/zsh";

  # Enable passwd and co.
  users.mutableUsers = true;

  # My user account
  users.extraUsers.barrucadu = {
    uid = 1000;
    description = "Michael Walker <mike@barrucadu.co.uk>";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    group = "users";
    initialPassword = "breadbread";

    # Such pubkey!
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDILnZ0gRTqD6QnPMs99717N+j00IEESLRYQJ33bJ8mn8kjfStwFYFhXvnVg7iLV1toJ/AeSV9jkCY/nVSSA00n2gg82jNPyNtKl5LJG7T5gCD+QaIbrJ7Vzc90wJ2CVHOE9Yk+2lpEWMRdCBLRa38fp3/XCapXnt++ej71WOP3YjweB45RATM30vjoZvgw4w486OOqhoCcBlqtiZ47oKTZZ7I2VcFJA0pzx2sbArDlWZwmyA4C0d+kQLH2+rAcoId8R6CE/8gsMUp8xdjg5r0ZxETKwhlwWaMxICcowDniExFQkBo98VbpdE/5BfAUDj4fZLgs/WRGXZwYWRCtJfrL barrucadu@azathoth"

      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKt4UgnpCo+6YBXfSc1cm9zhGwwLcENpN/XZUPOQunA505kqzuAqdW6lYGOl4VKNVebSKXRtqjKuGC4N/mi4eudiA8nwnwsPAWNofa047mx6+a9lzkQlWDMWP43exozMxraKSDFdvwwCjcS4GmhBZHJipcrEJX0TEq29SPszA0X0G0vFPC6+V3qfIUtY0BhSm7BYYh+hjS/muplpmV5XfZfBCvN2FMipPtPDRfdOgxWZHB2dg/gDkEkkHKMRU2G4IwaYdRzfCyyju/OaeK313j+dnJVn42LloPTpt0rtas7fi7nCWsdBZ1dPjU1HWcplf7iXR+HXxGYX1/yuUz6SyD barrucadu@nyarlathotep"

      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCZu6N6RBj6LZ2mXdVgfv/6EOxQlRIAXrrBx5HVbPFamtzLyy4wJ9rwuKYmf9zQ8pIhYMS1LqgeRBSPoRDQ2f7KFrI/y+q23un9qbh/k6exKNJqcSYez6bmcoB4kH+jK+TsEYBv5y3jOdMTwhRXzE774JHTnoTNqTB8on9Bz92UXuCecneBVfbdNWD8qBc+SYZYAOxjfAgmz16uSQN/XWhqJb/7Co0K5Rkb23barUUuwm06TXZUfw5mnzkkd2An5vtnicWR9Y50H+ErtcZwLLwMUkkft69QaqnQzgKd6aWvU2GVwefDgM6mG77EheNbqnjsXJP8C17hBT7L78r41C3d barrucadu@runciman"

      "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAy2BMP8hXKn2OeEWmVzhVpnMf4CGuMfN5fMW5PqndxxEmrUNIGOJYjzhJPaZvbHCZf8n6aUnjmjVdcKq/NWVE6b6ui1WZYcb88vG/Dv2pqF+mCO2Ol/8goH/WgruHpZhRJ1GFJrqhd0w2cWhcfZHGFHKy8m6xm9nrR1wuNlpFZi9JvjCa/6y4K+Sdu0vNkZ8/p5rj1DXR0rXmDmd7+j3wadiZf0uelDxB2QMkMplETt2x9B74Yj+ddRkR5Ql43McShWvL+m/lqOEFNX8EQKAmPmfcTilqgnKf1pg/7bG9j7FlJj9ulL1kZFllNyGuGm24UUAfQphwMPKmKr1oFSMUDDk+xsI40Pb3Fi9vIKtvxTxlu5Kv2RVF+8wpZP/J2LXhjVEMpTXJdAty8UszHSe1aNF4g0pEMlXCePeVD8HayAxeRUhUl/lctFcB9JH0sNS7jojFHfGIBmq3DEPDNndbVA9uAhKs3zOHQDD15v18NO55JQ7a4o8IpcOj2pyaUJ6l0VyNco4V4cpusYcMF0zDJei+TE98GqdFn8W97ulDyi6K2RMrWL8wADS8R1Z9E+2hu9ola/A0TWDFpIhy94pqKAVDJNqg6+i1OwpiBYKiWm+dlrKz9IMF86gv9GX0g6KpEIHDnqbVxL1jOqGFfQIyKExZpBRWffxp60slegotcZc= putty-arkham"

      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkI6P8XPkAQ/L7mmZY9EXQfHhmrd2ImYPEqExDUa+3xHJWw2Ha8gJ5EMk36QcTHFwok9dWuvjHk+ZCeodW99euuB6ZIuKjIb5Ru+3ZJvWisykTV32Tl+P1Pgi0BijKo9GFk2HJ3HemR2n0cZXvyEJuUvKwncdPWt6Fsr629gPcT7I6M/HwdXLHt9c7r64GhRCLcthKptUDGhVFls9v0w7ReNFjq81P9NO2SvPPJfGO7aAW96QyQdlF4OdtZyOTBy2Fr0FoHNrOZQ6XtwjnY5K8SZ68J05Fy/rHDt7bO3X2dcROnQTWHBMVSjLYnLlL5xlQBp0fj/VblRkiCuoVduT3 msw504@csteach0"

      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCqFnuZJcbvP4RwgByxQ/+Sr8UxzBbAAjLhmhwuu1dhC0apcV6ou9fPmHyWvvgeNPV7t/FCOBzYRsprsuP6Lf42UgXdVe1JF9nRh+jB7q0y/YTe44usPePMV9d556M4sO1P2FcuvyZy5V6Gquz/fyj65qZL/bHgbjvVDub7tScInbYQ+jFJwrPo0DOAmDvNtybDg4betk8bb2eI7kcEWBaIA+rdNHTCNzZGNq1uOgtLb2G0b4+hQJr7tLoN613hhRIhfWH//GShTLfLH2FjndXGNv3Ly84MerlM1SCOHnrBiojSAzXa9aXSWHNBwE+Tbvw2afGx1L+sTwCG/TFFz5gF barrucadu@yig"
    ];
  };

  # Give all normal users a ~/tmp
  systemd.tmpfiles.rules =
    let mkTmpDir = n: u: "d ${u.home}/tmp 0700 ${n} ${u.group} 7d";
    in mapAttrsToList mkTmpDir (filterAttrs (n: u: u.isNormalUser) config.users.extraUsers);
}
