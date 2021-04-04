{ baseURI
, dockerVolumeDir
, image
, esTag ? "7.11.2"
, httpPort ? 3000
, internalHTTP ? true
, readOnly ? false
, ...
}:

''
  version: "3"

  services:
    bookdb:
      image: ${image}
      restart: always
      environment:
        ALLOW_WRITES: "${if readOnly then "0" else "1"}"
        BASE_URI: "${baseURI}"
        COVER_DIR: "/bookdb-covers"
        ES_HOST: "http://db:9200"
      networks:
        - bookdb
      ports:
        - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:8888"
      volumes:
        - ${toString dockerVolumeDir}/covers:/bookdb-covers
      depends_on:
        - db

    db:
      image: elasticsearch:${esTag}
      restart: always
      environment:
        - http.host=0.0.0.0
        - discovery.type=single-node
        - ES_JAVA_OPTS=-Xms1g -Xmx1g
      networks:
        - bookdb
      volumes:
        - ${toString dockerVolumeDir}/esdata:/usr/share/elasticsearch/data

  networks:
    bookdb:
      external: false
''
