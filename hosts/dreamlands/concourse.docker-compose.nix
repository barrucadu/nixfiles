{ httpPort ? 3001
, internalHTTP ? true
, concourseTag ? "7.1"
, postgresTag ? "13"
, githubUser ? "barrucadu"
, githubClientId
, githubClientSecret
, enableSSM ? false
, ssmRegion ? "eu-west-1"
, ssmAccessKey ? ""
, ssmSecretKey ? ""
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
        ${if enableSSM then "CONCOURSE_AWS_SSM_REGION: \"${ssmRegion}\"" else ""}
        ${if enableSSM then "CONCOURSE_AWS_SSM_ACCESS_KEY: \"${ssmAccessKey}\"" else ""}
        ${if enableSSM then "CONCOURSE_AWS_SSM_SECRET_KEY: \"${ssmSecretKey}\"" else ""}
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
      driver: local
      driver_opts:
        o: bind
        type: none
        device: /docker-volumes/concourse/postgres/${postgresTag}
''
