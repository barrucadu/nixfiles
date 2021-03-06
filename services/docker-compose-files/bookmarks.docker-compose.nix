{ baseURI
, dockerVolumeDir
, image
, esTag ? "7.11.2"
, httpPort ? 3000
, readOnly ? false
, youtubeApiKey ? null
, ...
}:

''
  version: "3"

  services:
    bookmarks:
      image: ${image}
      restart: always
      environment:
        ALLOW_WRITES: "${if readOnly then "0" else "1"}"
        BASE_URI: "${baseURI}"
        ES_HOST: "http://db:9200"
        YOUTUBE_API_KEY: "${if youtubeApiKey == null then "" else youtubeApiKey}"
      ports:
        - "127.0.0.1:${toString httpPort}:8888"
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
