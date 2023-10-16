Upgrade to a new version of postgres
====================================


Change the default postgres version for a module
------------------------------------------------

1. Individually upgrade all hosts to the new version, following the processes below.
2. Change the default value of the `postgresTag` option for the module.
3. Remove the per-host `postgresTag` options.


Upgrade to a new minor version
------------------------------

This is generally safe.  Just change the `postgresTag` and rebuild the NixOS
configuration.


Upgrade to a new major version
------------------------------

In brief: take a backup, shut down the database, bring up the new one, and
restore the backup.  This does have some downtime, but is relatively risk free.

Shell variables:

- `$CONTAINER` - the database container name
- `$POSTGRES_DB` - the database name
- `$POSTGRES_USER` - the database user
- `$POSTGRES_PASSWORD` - the database password
- `$VOLUME_DIR` - the directory on the host that the container's `/var/lib/postgresql/data` is bind-mounted to
- `$TAG` - the new container tag to use

Replace `podman` with `docker` in the following commands if you're using that.

1. Stop all services which write to the database.

2. Dump the database:

    ```bash
    sudo podman exec -i "$CONTAINER" pg_dump -U "$POSTGRES_USER" --no-owner -Fc "$POSTGRES_DB" > "${CONTAINER}.dump"
    ```

3. Stop the database container:

    ```bash
    sudo systemctl stop "podman-$CONTAINER"
    ```

4. Back up the database volume:

    ```bash
    sudo mv "$VOLUME_DIR" "${VOLUME_DIR}.bak"
    ```

5. Create the new volume:

    ```bash
    sudo mkdir "$VOLUME_DIR"
    ```

6. Bring up a new database container with the dump bind-mounted into it:

    ```bash
    sudo podman run --rm --name="$CONTAINER" -v "$(pwd):/backup" -v "${VOLUME_DIR}:/var/lib/postgresql/data" -e "POSTGRES_DB=${POSTGRES_DB}" -e "POSTGRES_USER=${POSTGRES_USER}" -e "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" "postgres:${TAG}"
    ```

7. In another shell, restore the dump:

    ```bash
    sudo podman exec "$CONTAINER" pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -j4 --clean "/backup/${CONTAINER}.dump"
    ```

8. Ctrl-c the database container after the dump has restored successfully.

9. Change the `postgresTag` option in the host's NixOS configuration.

10. Rebuild the NixOS configuration and check that the database and all of its dependent services come back up:

    ```bash
    sudo nixos-rebuild switch
    ```

### Rollback

The old database files are still present at `${VOLUME_DIR}.bak`, so:

1. Stop all the relevant services, including the database container.

2. Restore the backup:

    ```bash
    sudo mv "$VOLUME_DIR" "${VOLUME_DIR}.aborted"
    sudo mv "${VOLUME_DIR}.bak" "$VOLUME_DIR"
    ```

3. If the `postgresTag` has been updated in the NixOS configuration:

    1. Revert it to its previous version.
    2. Rebuild the NixOS configuration.

4. Restart all the relevant services.
