{ httpPort     ? 3001
, internalHTTP ? true
, eventApiTag  ? "latest"
, postgresTag  ? "13"
, jwtSecret
}:

''
version: "2"

services:
  event_api_server:
    image: registry.barrucadu.dev/event-api-server:${eventApiTag}
    restart: always
    environment:
      PG_HOST: db
      PG_USERNAME: event-api-server
      PG_PASSWORD: event-api-server
      PG_DB: event-api-server
      JWT_SECRET: "${jwtSecret}"
    networks:
      - event_api_server
    ports:
      - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:3000"
    depends_on:
      - db

  db:
    image: postgres:${postgresTag}
    restart: always
    environment:
      POSTGRES_DB: event-api-server
      POSTGRES_PASSWORD: event-api-server
      POSTGRES_USER: event-api-server
      PGDATA: /database
    networks:
      - event_api_server
    volumes:
      - event_api_server_postgres:/database

networks:
  event_api_server:
    external: false

volumes:
  event_api_server_postgres:
    driver: local
    driver_opts:
      o: bind
      type: none
      device: /docker-volumes/event-api-server/postgres/${postgresTag}
''
