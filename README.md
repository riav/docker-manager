# Docker-Manager Version: [v0.1.1](https://github.com/riav/docker-manager/blob/master/CHANGELOG.md#v011-2018-01-14)

Docker image that manages other dockers in stadalone mode.

It is created as a service in swarm and runs and controls N dockers configured in docker-manager.cfg in standalone mode.
So if the docker host drops or the service migrates for some reason, dockers managed by docker-manager are disconnected and started on the new host that the service is instantiated.

Available from docker hub as [riav/docker-manager](https://hub.docker.com/r/riav/docker-manager/)

# [Changelog](https://github.com/riav/docker-manager/blob/master/CHANGELOG.md)

# How it does this:

[Wiki - How it does this](https://github.com/riav/docker-manager/wiki#how-it-does-this)

## Usage
    docker service create --name test-01 --replicas 1 \
                        --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
                        --mount type=bind,source=/logs-test-01,destination=/var/log/docker-manager \
                        --mount type=bind,source=/docker-manager.cfg,destination=/docker-manager.cfg \
                        --restart-condition any riav/docker-manager
## For testing and development with docker api
    docker run -d -v /var/run/docker.sock:/var/run/docker.sock riav/docker-manager --mode-run
### docker-manager.cfg
    Supports comment with #
    # Docker apache with ip...
    
    --name string                    Assign a name to the container
    --hostname string                Container host name
    --cpu-period int                 Limit CPU CFS (Completely Fair Scheduler) period
    --cpu-quota int                  Limit CPU CFS (Completely Fair Scheduler) quota
    --cpu-rt-period int              Limit CPU real-time period in microseconds
    --cpu-rt-runtime int             Limit CPU real-time runtime in microseconds
    -c, --cpu-shares int             CPU shares (relative weight)
    --cpus decimal                   Number of CPUs
    --cpuset-cpus string             CPUs in which to allow execution (0-3, 0,1)
    --cpuset-mems string             MEMs in which to allow execution (0-3, 0,1)
    --net, --network string          Connect a container to a network
    --ip string                      IPv4 address (e.g., 172.30.100.104)
    --ip6 string                     IPv6 address (e.g., 2001:db8::33)
    --mac-address string             Container MAC address (e.g., 92:d0:c6:0a:29:33)
    *For a correct syntax, first declare the network (--net) and then (--ip) and/or (--ip6) and/or (--mac-address), if you want to specify.
    -e, --env list                   Set environment variables
    -l, --label list                 Set meta data on a container
    --kernel-memory bytes            Kernel memory limit (support b, k, m, g)
    -m, --memory bytes               Memory limit (support b, k, m, g)
    --memory-reservation bytes       Memory soft limit (support b, k, m, g)
    --memory-swap bytes              Swap limit equal to memory plus swap: '-1' to enable unlimited swap (support b, k, m, g)
    --memory-swappiness int          Tune container memory swappiness (0 to 100) (default -1)
    --entrypoint string              Overwrite the default ENTRYPOINT of the image
    --oom-kill-disable               Disable OOM Killer
    --oom-score-adj int              Tune host's OOM preferences (-1000 to 1000)
    --pids-limit int                 Tune container pids limit (set -1 for unlimited)
    --privileged                     Give extended privileges to this container
    --read-only                      Mount the container's root filesystem as read only
    --restart string                 Restart policy to apply when a container exits. Required argument (always, unless-stopped, on-failure)
    --rm(implicit)                   Automatically remove the container when it exits. Used by default if --restart is not declared
    --shm-size bytes                 Size of /dev/shm (support b, k, m, g)
    --storage-opt list               Storage driver options for the container
    -v, --volume list                Bind mount a volume

# Example:
    #Test-01
    --name test-01 -v /root.txt:/root.txt --privileged -e FOO=bar --label test.version=1.0 --memory 2g \
    --net lan --ip 192.168.1.100 \
    --net net-swarm centos:6 sleep infinity
