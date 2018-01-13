FROM alpine
LABEL docker.manager.master.server "true"
LABEL docker.manager.maintainer "RIAV - Rafael Igor <rafael.igor@gmail.com>"
LABEL docker.manager.url "https://github.com/riav/manager"
LABEL docker.manager.version="0.1.0" docker.manager.volumes=":/var/run/docker.sock :/docker-manager.cfg" docker.manager.env="DOCKER_SOCK=/var/run/docker.sock" docker.manager.jq="1.5" docker.manager.from="alpine"
RUN apk add --no-cache curl &&\
    curl -L'#' https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 > /usr/local/bin/jq-1.5-linux64 &&\
    chmod +x /usr/local/bin/jq-1.5-linux64 && ln -s /usr/local/bin/jq-1.5-linux64 /usr/local/bin/jq &&\
    touch /docker-manager.cfg
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
