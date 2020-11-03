{ httpPort     ? 3001
, internalHTTP ? true
, concourseTag ? "6.7"
, postgresTag  ? "9.6"
, githubUser   ? "barrucadu"
, githubClientId
, githubClientSecret
}:

''
version: "2"

services:
  concourse:
    image: concourse/concourse:${concourseTag}
    command: quickstart
    privileged: true
    restart: always
    environment:
      CONCOURSE_POSTGRES_HOST: db
      CONCOURSE_POSTGRES_USER: concourse
      CONCOURSE_POSTGRES_PASSWORD: concourse
      CONCOURSE_POSTGRES_DATABASE: concourse
      CONCOURSE_EXTERNAL_URL: "https://cd.barrucadu.dev"
      CONCOURSE_MAIN_TEAM_GITHUB_USER: "${githubUser}"
      CONCOURSE_GITHUB_CLIENT_ID: "${githubClientId}"
      CONCOURSE_GITHUB_CLIENT_SECRET: "${githubClientSecret}"
      CONCOURSE_LOG_LEVEL: error
      CONCOURSE_GARDEN_LOG_LEVEL: error
    networks:
      - concourse
    ports:
      - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:8080"
    depends_on:
      - db

  db:
    image: postgres:${postgresTag}
    restart: always
    environment:
      POSTGRES_DB: concourse
      POSTGRES_PASSWORD: concourse
      POSTGRES_USER: concourse
      PGDATA: /database
    networks:
      - concourse
    volumes:
      - concourse_postgres:/database

networks:
  concourse:
    external: false

volumes:
  concourse_postgres:
''
