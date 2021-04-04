{ dockerVolumeDir
, image
, httpPort ? 3000
, pgTag ? "13"
, ...
}:

''
  version: "3"

  services:
    etherpad:
      image: ${image}
      restart: always
      environment:
        DB_TYPE: "postgres"
        DB_HOST: "db"
        DB_PORT: "5432"
        DB_NAME: "etherpad"
        DB_USER: "etherpad"
        DB_PASS: "etherpad"
        TRUST_PROXY: "true"
      ports:
        - "127.0.0.1:${toString httpPort}:9001"
      depends_on:
        - db

    db:
      image: postgres:${pgTag}
      restart: always
      environment:
        POSTGRES_USER: etherpad
        POSTGRES_PASSWORD: etherpad
        POSTGRES_DB: etherpad
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data
''
