{ httpPort ? 3000
, sshPort ? 222
, internalHTTP ? true
, internalSSH ? false
, giteaTag ? "1.13.4"
, postgresTag ? "13"
, dockerVolumeDir
}:

''
  version: "2"

  services:
    server:
      image: gitea/gitea:${giteaTag}
      environment:
        - APP_NAME="barrucadu.dev git"
        - RUN_MODE=prod
        - ROOT_URL=https://git.barrucadu.dev
        - SSH_DOMAIN=barrucadu.dev
        - SSH_PORT=${toString sshPort}
        - SSH_LISTEN_PORT=22
        - HTTP_PORT=3000
        - DB_TYPE=postgres
        - DB_HOST=db:5432
        - DB_NAME=gitea
        - DB_USER=gitea
        - DB_PASSWD=gitea
        - USER_UID=1000
        - USER_GID=1000
      restart: always
      networks:
        - gitea
      volumes:
        - ${toString dockerVolumeDir}/data:/data
      ports:
        - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:3000"
        - "${if internalSSH then "127.0.0.1:" else ""}${toString sshPort}:22"
      depends_on:
        - db

    db:
      image: postgres:${postgresTag}
      restart: always
      environment:
        - POSTGRES_USER=gitea
        - POSTGRES_PASSWORD=gitea
        - POSTGRES_DB=gitea
      networks:
        - gitea
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data

  networks:
    gitea:
      external: false
''
