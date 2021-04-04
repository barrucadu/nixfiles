{ httpPort ? 3005
, internalHTTP ? true
, umamiTag ? "postgresql-latest"
, postgresTag ? "13"
, hashSalt
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
      networks:
        - umami
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
      networks:
        - umami
      volumes:
        - umami_pgdata:/var/lib/postgresql/data

  networks:
    umami:
      external: false

  volumes:
    umami_pgdata:
      driver: local
      driver_opts:
        o: bind,
        type: none,
        device: /persist/docker-volumes/umami/pgdata
''
