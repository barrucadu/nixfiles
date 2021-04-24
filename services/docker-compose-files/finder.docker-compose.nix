{ dockerVolumeDir
, image
, mangaDir
, esTag ? "7.11.2"
, httpPort ? 3000
, ...
}:

''
  version: "3"

  services:
    finder:
      image: ${image}
      restart: always
      environment:
        DATA_DIR: "/data"
        ES_HOST: "http://db:9200"
      ports:
        - "127.0.0.1:${toString httpPort}:8888"
      volumes:
        - ${toString mangaDir}:/data
      depends_on:
        - db

    db:
      image: elasticsearch:${esTag}
      restart: always
      environment:
        - http.host=0.0.0.0
        - discovery.type=single-node
        - ES_JAVA_OPTS=-Xms512M -Xmx512M
      volumes:
        - ${toString dockerVolumeDir}/esdata:/usr/share/elasticsearch/data
''
