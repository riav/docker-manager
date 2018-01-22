# Changelog
## v0.2.0 (2018-01-21)

**Implemented enhancements:**

- Add option --privileged
- Add option --read-only
- Add option --oom-kill-disable
- Add option --oom-score-adj
- Add option --shm-size
- Add option --pids-limit
- Add option --cpu-period
- Add option --cpu-quota
- Add option --cpu-rt-period
- Add option --cpu-rt-runtime
- Add option --cpu-shares, -c
- Add option --cpus
- Add option --cpuset-cpus
- Add option --cpuset-mems
- Add option --kernel-memory
- Add option --memory, -m
- Add option --memory-reservation
- Add option --memory-swap
- Add option --memory-swappiness
- Add option --mac-address
- Add option --label
- Add option --entrypoint
- Add option --storage-opt
- Add option --network-disabled
- Support for logs (/var/log/docker-manager).
- Agent Name Change: Monitor for Garbage Collector(GC).
- Implemented line break(\) for docker-manager.cfg.
- Changed the kill mode of the slaves dockers through the GC. Before it was with kill, now with DELETE.
- Code enhancements.
- Bugs found in the previous version.

## v0.1.1 (2018-01-14)

**Implemented enhancements:**

- Add command --mode-run to run tests and development with the docker API.
- Add option --ip6 to support IPV6 Networks.
- Code enhancements.
- Removed standby option when file docker-manager.cfg is empty, now manager left.
- Changed the stop mode of the slaves dockers through the monitor. Before it was with stop, now with kill.

## v0.1.0 (2018-01-12)

**First Version**
