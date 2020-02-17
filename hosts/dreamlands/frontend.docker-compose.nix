{ httpPort     ? 3001
, internalHTTP ? true
, frontendTag  ? "latest"
}:

''
version: "2"

services:
  frontend:
    image: registry.barrucadu.dev/frontend:${frontendTag}
    restart: always
    ports:
      - "${if internalHTTP then "127.0.0.1:" else ""}${toString httpPort}:3000"
''
