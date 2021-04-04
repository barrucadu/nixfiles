{ dockerVolumeDir
, hashSalt
, httpPort ? 3005
, internalHTTP ? true
, postgresTag ? "13"
, umamiTag ? "postgresql-latest"
, ...
}:

''
  version: "3"

  services:
    server:
      image: ghcr.io/mikecao/umami:${umamiTag}
      restart: always
      environment:
        DATABASE_URL: postgres://umami:umami@db/umami
        HASH_SALT: ${hashSalt}
      ports:
        - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:3000"
      depends_on:
        - db

    db:
      image: postgres:${postgresTag}
      restart: always
      environment:
        POSTGRES_DB: umami
        POSTGRES_USER: umami
        POSTGRES_PASSWORD: umami
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data
''
