{ dockerVolumeDir
, hashSalt
, httpPort ? 3005
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
        - "127.0.0.1:${toString httpPort}:3000"
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
