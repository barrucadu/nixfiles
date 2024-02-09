ZPoolStatusDegraded
===================

This alert fires when an HDD fails.

The `zpool status -x` command will say which drive has failed; what,
specifically, the problem is; and link to a runbook:

```
$ zpool status -x
  pool: data
 state: DEGRADED
status: One or more devices could not be used because the label is missing or
        invalid.  Sufficient replicas exist for the pool to continue
        functioning in a degraded state.
action: Replace the device using 'zpool replace'.
   see: https://openzfs.github.io/openzfs-docs/msg/ZFS-8000-4J
  scan: scrub in progress since Thu Feb  1 00:00:01 2024
        19.3T / 20.6T scanned at 308M/s, 17.8T / 20.6T issued at 284M/s
        0B repaired, 86.49% done, 02:51:42 to go
config:

        NAME                                         STATE     READ WRITE CKSUM
        data                                         DEGRADED     0     0     0
          mirror-0                                   DEGRADED     0     0     0
            11478606759844821041                     UNAVAIL      0     0     0  was /dev/disk/by-id/ata-ST10000VN0004-1ZD101_ZA206882-part2
            ata-ST10000VN0004-1ZD101_ZA27G6C6-part2  ONLINE       0     0     0
          mirror-1                                   ONLINE       0     0     0
            ata-ST10000VN0004-1ZD101_ZA22461Y        ONLINE       0     0     0
            ata-ST10000VN0004-1ZD101_ZA27BW6R        ONLINE       0     0     0
          mirror-2                                   ONLINE       0     0     0
            ata-ST10000VN0008-2PJ103_ZLW0398A        ONLINE       0     0     0
            ata-ST10000VN0008-2PJ103_ZLW032KE        ONLINE       0     0     0

errors: No known data errors
```

Follow the provided runbook.  In most cases the solution will be to:

1. Buy a new HDD (of at least the same size as the failed one)
1. Physically replace the failed HDD with the new one
1. Run `zpool replace <pool> <old-device> <new-device>`
1. Wait for the new device to resilver
