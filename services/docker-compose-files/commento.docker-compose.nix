{ dockerVolumeDir
, externalUrl
, commentoTag ? "latest"
, forbidNewOwners ? true
, githubKey ? null
, githubSecret ? null
, googleKey ? null
, googleSecret ? null
, httpPort ? 3004
, internalHTTP ? true
, postgresTag ? "13"
, twitterKey ? null
, twitterSecret ? null
, ...
}:

''
  version: "3"

  services:
    server:
      image: registry.gitlab.com/commento/commento:${commentoTag}
      restart: always
      environment:
        COMMENTO_ORIGIN: ${externalUrl}
        COMMENTO_PORT: 8080
        COMMENTO_POSTGRES: postgres://commento:commento@db/commento?sslmode=disable
        COMMENTO_FORBID_NEW_OWNERS: "${if forbidNewOwners then "true" else "false"}"
        ${if githubKey != null then "COMMENTO_GITHUB_KEY: \"${githubKey}\"" else ""}
        ${if githubSecret != null then "COMMENTO_GITHUB_SECRET: \"${githubSecret}\"" else ""}
        ${if googleKey != null then "COMMENTO_GOOGLE_KEY: \"${googleKey}\"" else ""}
        ${if googleSecret != null then "COMMENTO_GOOGLE_SECRET: \"${googleSecret}\"" else ""}
        ${if twitterKey != null then "COMMENTO_TWITTER_KEY: \"${twitterKey}\"" else ""}
        ${if twitterSecret != null then "COMMENTO_TWITTER_SECRET: \"${twitterSecret}\"" else ""}
      ports:
        - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:8080"
      depends_on:
        - db

    db:
      image: postgres:${postgresTag}
      restart: always
      environment:
        POSTGRES_DB: commento
        POSTGRES_USER: commento
        POSTGRES_PASSWORD: commento
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data
''
