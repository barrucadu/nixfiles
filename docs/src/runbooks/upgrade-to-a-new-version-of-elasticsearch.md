Upgrade to a new version of elasticsearch
====================================


Change the default elasticsearch version for a module
-----------------------------------------------------

1. Individually upgrade all hosts to the new version, following the processes below.
2. Change the default value of the `elasticsearchTag` option for the module.
3. Remove the per-host `elasticsearchTag` options.


Upgrade to a new minor version
------------------------------

This is generally safe.  Just change the `elasticsearchTag` and rebuild the NixOS
configuration.


Upgrade to a new major version
------------------------------

In brief: take a backup, upgrade to the latest minor release of the current
major version, fix any application warnings, and then upgrade to the initial
release of the new major version.

Shell variables:

- `$VOLUME_DIR` - the directory on the host that the container's `/usr/share/elasticsearch/data` is bind-mounted to

1. Upgrade to the latest minor release of the current major version.

    1. Change the `elasticsearchTag` option in the host's NixOS configuration to the latest minor release of the current major version.

    2. Rebuild the NixOS configuration and check that the database and all of its dependent services come back up:

        ```bash
        sudo nixos-rebuild switch
        ```

2. Exercise the application, performing both reads and writes: check the elasticsearch log for deprecation warnings, and fix any issues in the application.

3. Stop the database.

4. Take a backup:

    ```bash
    sudo cp -a "$VOLUME_DIR" "${VOLUME_DIR}.bak"
    ```

5. Change the `elasticsearchTag` option in the host's NixOS configuration to the initial release of the new major version.

6. Rebuild the NixOS configuration and check that the database and all of its dependent services come back up:

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

3. If the `elasticsearchTag` has been updated in the NixOS configuration:

    1. Revert it to its previous version.
    2. Rebuild the NixOS configuration.

4. Restart all the relevant services.
