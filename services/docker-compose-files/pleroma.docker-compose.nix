{ dockerVolumeDir
, domain
, image
, secretsFile
, adminEmail ? "mike@barrucadu.co.uk"
, faviconPath ? null
, httpPort ? 4000
, instanceName ? domain
, notifyEmail ? adminEmail
, pgTag ? "13"
, ...
}:

''
  version: "3"

  services:
    pleroma:
      image: ${image}
      restart: always
      environment:
        DOMAIN: "${domain}"
        INSTANCE_NAME: "${instanceName}"
        ADMIN_EMAIL: "${adminEmail}"
        NOTIFY_EMAIL: "${notifyEmail}"
        DB_USER: "pleroma"
        DB_PASS: "pleroma"
        DB_NAME: "pleroma"
        DB_HOST: "db"
      ports:
        - "127.0.0.1:${toString httpPort}:4000"
      volumes:
        - ${toString dockerVolumeDir}/uploads:/var/lib/pleroma/uploads
        - ${toString dockerVolumeDir}/emojis:/var/lib/pleroma/static/emoji/custom
        - ${secretsFile}:/var/lib/pleroma/secret.exs
        ${if faviconPath == null then "" else "- ${faviconPath}:/var/lib/pleroma/static/favicon.png"}
      depends_on:
        - db

    db:
      image: postgres:${pgTag}
      restart: always
      environment:
        POSTGRES_USER: pleroma
        POSTGRES_PASSWORD: pleroma
        POSTGRES_DB: pleroma
      volumes:
        - ${toString dockerVolumeDir}/pgdata:/var/lib/postgresql/data
''
