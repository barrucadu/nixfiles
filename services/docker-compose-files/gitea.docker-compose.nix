{ dockerVolumeDir
, giteaTag ? "1.13.4"
, httpPort ? 3000
, postgresTag ? "13"
, sshPort ? 222
, ...
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
      volumes:
        - ${toString dockerVolumeDir}/data:/data
      ports:
        - "127.0.0.1:${toString httpPort}:3000"
        - "${toString sshPort}:22"
      depends_on:
        - db

    db:
      image: postgres:${postgresTag}
      restart: always
      environment:
        - POSTGRES_USER=gitea
        - POSTGRES_PASSWORD=gitea
        - POSTGRES_DB=gitea
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data
''
