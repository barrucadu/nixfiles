DiskSpaceLow
============

This alert fires when a partition has under 10% free space remaining.

The alert will say which partitions are affected, `df -h` also has the
information:

```
$ df -h
Filesystem                Size  Used Avail Use% Mounted on
devtmpfs                  1.6G     0  1.6G   0% /dev
tmpfs                      16G  112K   16G   1% /dev/shm
tmpfs                     7.8G  9.8M  7.8G   1% /run
tmpfs                      16G  1.1M   16G   1% /run/wrappers
local/volatile/root       1.7T  1.8G  1.7T   1% /
local/persistent/nix      1.7T  5.1G  1.7T   1% /nix
local/persistent/persist  1.7T  2.0G  1.7T   1% /persist
local/persistent/var-log  1.7T  540M  1.7T   1% /var/log
efivarfs                  128K   40K   84K  33% /sys/firmware/efi/efivars
local/persistent/home     1.7T   32G  1.7T   2% /home
/dev/nvme0n1p2            487M   56M  431M  12% /boot
data/nas                   33T   22T   11T  68% /mnt/nas
tmpfs                     3.2G   12K  3.2G   1% /run/user/1000
```

Note all ZFS datasets in the same pool (`local/*` and `data/*` in the example
above) share the underlying storage.

Debugging steps:

- See the `node_filesystem_avail_bytes` metric for how quickly disk space is
  being consumed
- Use `ncdu -x` to work out where the space is going
- Buy more storage if need be
