{ dockerVolumeDir
, githubClientId
, githubClientSecret
, concourseTag ? "7.1"
, enableSSM ? false
, githubUser ? "barrucadu"
, httpPort ? 3001
, postgresTag ? "13"
, ssmAccessKey ? null
, ssmRegion ? "eu-west-1"
, ssmSecretKey ? null
, workerScratchDir ? null
, ...
}:

''
  version: "2"

  services:
    web:
      image: concourse/concourse:${concourseTag}
      command: web
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
      volumes:
        - ${toString dockerVolumeDir}/keys/web:/concourse-keys
      ports:
        - "127.0.0.1:${toString httpPort}:8080"
      depends_on:
        - db

    worker:
      image: concourse/concourse:${concourseTag}
      command: worker
      privileged: true
      restart: always
      environment:
        CONCOURSE_TSA_HOST: web:2222
        ${if workerScratchDir == null then "" else "CONCOURSE_WORK_DIR: \"/workdir\""}
      volumes:
        - ${toString dockerVolumeDir}/keys/worker:/concourse-keys
        ${if workerScratchDir == null then "" else "- ${workerScratchDir}:/workdir"}
      depends_on:
        - web

    db:
      image: postgres:${postgresTag}
      restart: always
      environment:
        POSTGRES_DB: concourse
        POSTGRES_PASSWORD: concourse
        POSTGRES_USER: concourse
        PGDATA: /database
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/database
''
