# Docker-Manager
Docker image that manages other dockers in stadalone mode (macvlan).
## Usage
  docker service create --name manager_xpto --replicas 1 \
                        --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
                        --mount type=bind,source=/docker-manager.cfg,destination=/docker-manager.cfg \
                        --restart-condition any riav/docker-manager
