# Docker-Manager Version: [v0.1.0](https://github.com/riav/docker-manager/blob/master/CHANGELOG.md#v010-2018-01-12)

Docker image that manages other dockers in stadalone mode.\
It is created as a service in swarm and runs and controls N dockers configured in docker-manager.cfg in standalone mode.\
So if the docker host drops or the service migrates for some reason, dockers managed by docker-manager are disconnected and started on the new host that the service is instantiated.

Available from docker hub as [riav/docker-manager](https://hub.docker.com/r/riav/docker-manager/)

# How it does this:

[Wiki - How it does this](https://github.com/riav/docker-manager/wiki#how-it-does-this)

## Usage
  docker service create --name manager_xpto --replicas 1 \ \
                        --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \ \
                        --mount type=bind,source=/docker-manager.cfg,destination=/docker-manager.cfg \ \
                        --restart-condition any riav/docker-manager
### docker-manager.cfg
    Name of docker (docker ps).
    --name xpto
    
    Mounts volumes in docker conatiner.
    -v|--volume /root.txt:/root.txt

    Declares variables to docker container.
    -e|--env FOO=bar

    Connects the network present on the host to the docker container (docker network ls).
    --net|--network net-xpto

    Assigns an IP address to the docker container belonging to a previously declared network.
    --ip 192.168.200.100

    For a correct syntax, first declare the network (--net) and then the IP address (--ip), if you want to specify.

**Line break(\\) in docker-manager.cfg file not supported yet.**

# Example:
    #Test-01
    --name test-01 -v /root.txt:/root.txt -e FOO=bar --net lan --ip 192.168.1.100 --net net-swarm centos:6 sleep infinity
