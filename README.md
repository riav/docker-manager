# Docker-Manager
Docker image that manages other dockers in stadalone mode (macvlan).
## Usage
  docker service create --name manager_xpto --replicas 1 \\ \
                        --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \\ \
                        --mount type=bind,source=/docker-manager.cfg,destination=/docker-manager.cfg \\ \
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

# Example:
    #Teste-01
    --name teste-01 -v /root.txt:/root.txt -e FOO=bar --net lan --ip 192.168.1.100 --net net-swarm centos:6 sleep infinity
