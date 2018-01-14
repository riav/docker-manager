#!/bin/sh
#VERSION:0.1.1
CFG="/docker-manager.cfg"
CFG_TMP="/tmp/.docker-manager.cfg"
URL_CT="http:/docker/containers"
URL_NT="http:/docker/networks"
URL_IMG="http:/docker/images"
DOCKER_SOCK="/var/run/docker.sock"
CURL="curl -s --unix-socket ${DOCKER_SOCK}"
HEADER="Content-Type: application/json"
TIME_MONITOR_CHECK=5
TIME_MONITOR_SHUTDOWN=20
TIME_MODE_RUN=3600

function data {
 date "+%Y-%m-%d %H:%M:%S"
}

function docker_manager_monitor_start {
 echo "Starting docker-manager-monitor"
 MON_ERROR=""
 MNG_IMG=$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Image')
 if [ "${MNG_IMG}" != "" ]; then
  MASTER_ID_CUT=$(echo ${MASTER_ID}|cut -c1-12)
  CREATE_MON="create?name=${MASTER_NM}.monitor.${MASTER_ID_CUT}"
  DOCKER_SOCK_SRC=$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Mounts[]|select(.Destination=="'${DOCKER_SOCK}'")|.Source')
  BINDS="\"Binds\":[\"${DOCKER_SOCK_SRC}:${DOCKER_SOCK}\"]"
  #echo $BINDS
  MON_CMD="\"Cmd\":[\"--docker-manager-monitor\",\"${MASTER_ID}\"]"
  MON_ID=$($CURL -H "$HEADER" -d '{"Image":"'${MNG_IMG}'",'${MON_CMD}',"Labels":{"docker.manager.monitor.master":"'${MASTER_ID}'","docker.manager.master.server":"false"},'${BINDS}',"AutoRemove":true}' -X POST ${URL_CT}/${CREATE_MON})
  echo $MON_ID
  MON_ID=$(echo $MON_ID|jq -r .Id)
  [ "${MON_ID}" != "" ] && $CURL -X POST ${URL_CT}/${MON_ID}/start || MON_ERROR="ERROR: Could not create container Docker-Manager-monitor"
  sleep 5
  [ "${MON_ERROR}" = "" ] && MON_ERROR=$( [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MON_ID}'"))|map(select(.State=="running"))[]|.Id')" = "" ] && echo "Docker-Manager-monitor can not be started")
 else
    MON_ERROR="ERROR: Any Docker-Manager image found!!!!"
 fi
 if [ "${MON_ERROR}" != "" ]; then
  echo "$(data) $MON_ERROR"
  echo "Shutdown in ${TIME_MONITOR_SHUTDOWN}s..."
  sleep $TIME_MONITOR_SHUTDOWN
  exit 1
 else
  echo "$(data) Docker-Manager-monitor initialized [$MNG_IMG --docker-manager-monitor ${MASTER_ID}]"
 fi
}

if [ ! -e ${DOCKER_SOCK} ]; then
 echo "$(data) Docker Sock: [${DOCKER_SOCK}] not found. Try docker run -d -v /var/run/docker.sock:/var/run/docker.sock riav/docker-manager"
else
 #MODE RUN
 [ "$1" = "--mode-run" ] && while true; do echo "Mode run enabled"; sleep $TIME_MODE_RUN; done
 if [ "$1" = "--docker-manager-monitor" ]; then
  if [ "$2" = "" ]; then
   echo "$(data) ERROR: No parameter Master Docker-Manager id."
  else
   EXIT=0
   MASTER_ID=$2
   #Check if masterid is valid
   if [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))|map(select(.Labels."docker.manager.master.server"=="true"))[]|.Id')" = "" ]; then
    echo "$(data) ERROR: Id parameter does not belong to a Master."
    EXIT=1
   fi
   echo "$(data) Docker-Manager-monitor - Master id: ${MASTER_ID}"
   while [ ${EXIT} -eq 0 ]; do
    sleep $TIME_MONITOR_CHECK
    if [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))|map(select(.State=="running"))[]|.Id')" = "" ]; then
     for SLAVE_ID in $($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id'); do
      echo "Killing Slave Container id (${SLAVE_ID}...)"
      $CURL -X POST ${URL_CT}/${SLAVE_ID}/kill
      sleep 1
     done
     EXIT=1
     echo "Kill my self. by.."
    fi
   done
  fi
 else
  MASTER_ID=""
  MASTER_HN="$(hostname)"
  for ID in $($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.master.server"=="true"))[]|.Id'); do
   [ "$(echo $ID|cut -c1-12|grep $MASTER_HN)" != "" ] && MASTER_ID=$ID
  done
  MASTER_NM=$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Names[]'|cut -d'.' -f1)
  MASTER_NM=${MASTER_NM//\//}
  echo $(data)" SOCK: ${DOCKER_SOCK}"
  echo $(data)" Awaiting cleaning of slaves containers.."
  sleep 15
  #echo "Master: ${MASTER_NM}:${MASTER_ID}"
  while true; do
   #Iniciando docker-manager-monitor
   [ "$($CURL ${URL_CT}/json|jq -r 'map(select(.Labels."docker.manager.master.server"=="false"))|map(select(.Labels."docker.manager.monitor.master"=="'${MASTER_ID}'"))[]|.Id')" = "" ] && docker_manager_monitor_start
   #
   cat $CFG|grep -v ^# > ${CFG_TMP}
   if [ $(cat $CFG_TMP|wc -l) -eq 0 ]; then
    echo "No entries found in $CFG_TMP"
    echo "Exiting..."
    exit 1
   fi
   #Removing containers changed from /docker-manager.cfg
   SLAVES_UP=$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Labels."docker.manager.slave.cfg"')
   if [ "${SLAVES_UP}" != "" ]; then
    LIST_CFG_HASH=""
    for I in $(seq $(cat $CFG_TMP|wc -l)); do
     LIST_CFG_HASH=$LIST_CFG_HASH"$(head -$I $CFG_TMP|tail -1|md5sum|awk '{print $1}') "
    done
    LIST_CFG_HASH=" $LIST_CFG_HASH"
    for SLAVE in $SLAVES_UP; do
     if [ "$(echo "$LIST_CFG_HASH"|grep ' '${SLAVE}' ')" = "" ]; then
      ID_STOP=$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.slave.cfg"=="'${SLAVE}'"))|map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id')
      if [ "${ID_STOP}" != "" ]; then
       echo "$(data) Removing slave container $ID_STOP"
       $CURL -X POST ${URL_CT}/${ID_STOP}/stop
       sleep 5
      fi
     fi
    done
   fi
   for I in $(seq $(cat ${CFG_TMP}|wc -l)); do
    CREATE="create"; OPT=""; ENV=""; VOL=""; IPS6=""; IPS=""; NETS=""; NAME=""; NTWK=""; POS=-1; CFG_HASH=""; IMGCMD=""
    CFG_HASH=$(head -$I $CFG_TMP|tail -1|md5sum|awk '{print $1}')
    if [ "$CFG_HASH" != "d41d8cd98f00b204e9800998ecf8427e" ]; then
     if [ "x$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.slave.cfg"=="'$CFG_HASH'"))|map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id')" = "x" ]; then
      for VALUE in $(head -$I $CFG_TMP|tail -1|grep -v ^#); do
       NOPT=0
       case $OPT in
        'VOL') VOL="$VOL\"$VALUE\","; OPT="";;
        'IP') IPS="${IPS}#${POS}#${VALUE} "; OPT="";;
        'IP6') IPS6="${IPS6}#${POS}#${VALUE} "; OPT="";;
        'NET') NETS="${NETS}#${POS}#${VALUE} "; OPT="";;
        'NAME') NAME=$VALUE; OPT="";;
        'ENV') ENV="$ENV\"$VALUE\","; OPT="";;
        *) NOPT=1;;
       esac
       case $VALUE in
        '-v'|'--volume') OPT="VOL";;
        '--ip') OPT="IP";;
        '--ip6') OPT="IP6";;
        '--net'|'--network') OPT="NET"; POS=$(($POS+1));;
        '--name') OPT="NAME";;
        '-e'|'--env') OPT="ENV";;
        *) [ $NOPT -eq 1 ] && IMGCMD="${IMGCMD}${VALUE} ";;
       esac
      done
      #echo "N: ${NETS} - I: ${IPS}"
      if [ "x$NAME" != "x" ]; then
       #HTNAME="\"Hostname\":\"${MASTER_NM}.${NAME}\","
       #CREATE="${CREATE}?name=${MASTER_NM}.${NAME}"
       NAME="slave.${NAME}.${CFG_HASH}"
      else
      # #HTNAME="\"Hostname\":\"${MASTER_NM}.${MASTER_ID}\","
      # CREATE="${CREATE}?name=${MASTER_NM}.${NAME}"
       NAME="slave.$CFG_HASH"
      fi
      CREATE="${CREATE}?name=${MASTER_NM}.${NAME}"
      NET=$(echo $NETS|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
      if [ "$NET" != "" ]; then
       IP=$(echo $IPS|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
       IP6=$(echo $IPS6|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
       [ "${IP6}" != "" ] && IP6=",\"IPv6Address\":\"${IP6}\""
       NTWK=",\"NetworkingConfig\":{\"EndpointsConfig\":{\"${NET}\":{\"IPAMConfig\":{\"IPv4Address\":\"${IP}\"$IP6}}}}"
      fi
      if [ "x$VOL" != "x" ]; then
       VOL=${VOL%,}
       VOL=",\"Binds\":[$VOL]"
      fi
      IMG=""; CMD=""; FIMG=""
      for VAL in $IMGCMD; do
       if [ "x$FIMG" = "x" ]; then
        IMG="\"Image\":\"$VAL\""
        FIMG=$VAL
       else
        CMD="$CMD\"$VAL\","
       fi
      done
      if [ "x$FIMG" = "x" ]; then
       echo "No Imagem on $CFG in conf number $I"
      else
       IMGCMD=$IMG
       if [ "x$CMD" != "x" ]; then
        CMD=${CMD%,}
        IMGCMD=$IMG",\"Cmd\":[$CMD]"
       fi
       if [ "x$ENV" != "x" ]; then
        ENV=${ENV%,}
        ENV=",\"Env\":[$ENV]"
       fi
       echo "$(data) Geting Image ${FIMG}"
       $CURL -X POST ${URL_IMG}/create?fromImage=${FIMG}
       IP_USED=""
       for IP_ in $IPS; do
        IP=$(echo ${IP_}|awk -F'#' '{print $3}')
        [ "x$($CURL ${URL_CT}/json?all=1|jq .[].NetworkSettings|grep -i '"ip.*Address'|grep '"'${IP}'"')" != "x" ] && IP_USED=${IP}
       done
       if [ "x${IP_USED}" = "x" ]; then
        ID=$($CURL -H "$HEADER" -d '{'${HTNAME}${IMGCMD}',"Labels":{"docker.manager.slave.master":"'${MASTER_ID}'","docker.manager.slave.cfg":"'${CFG_HASH}'"}'${ENV}${VOL}',"AutoRemove":true'${NTWK}'}' -X POST ${URL_CT}/${CREATE})
        #echo "$CURL -H \"$HEADER\" -d '{${HTNAME}${IMGCMD},\"Labels\":{\"docker.manager.slave.master\":\"${MASTER_ID}\",\"docker.manager.slave.cfg\":\"${CFG_HASH}\"}${ENV}${VOL},\"AutoRemove\":true${NTWK}}' -X POST ${URL_CT}/${CREATE}"
        echo $ID
        ID=$(echo $ID|jq -r .Id)
        echo $(data)'{'${HTNAME}${IMGCMD}',"Labels":{"docker.manager.slave.master":"'${MASTER_ID}'","docker.manager.slave.cfg":"'${CFG_HASH}'"}'${ENV}${VOL}',"AutoRemove":true'${NTWK}'}'
        IP=""; for IP_ in $IPS; do IP="${IP}$(echo $IP_|awk '{print $1}'|grep -v '#0#') "; done; IPS=$IP
        IP6=""; for IP6_ in $IPS6; do IP6="${IP6}$(echo $IP6_|awk '{print $1}'|grep -v '#0#') "; done; IPS6=$IP6
        NET=""; for NET_ in $NETS; do NET="${NET}$(echo $NET_|awk '{print $1}'|grep -v '#0#') "; done; NETS=$NET
        Z=1
        IPCFG=""
        for NET_ in $NETS; do
         NET=$(echo $NET_|awk -F'#' '{print $3}')
         POS=$(echo $NET_|awk -F'#' '{print $2}')
         IP=$(echo $IPS|grep -o '#'${POS}'#.*'|awk '{print $1}'|awk -F'#' '{print $3}')
         IP6=$(echo $IPS6|grep -o '#'${POS}'#.*'|awk '{print $1}'|awk -F'#' '{print $3}')
         [ "x${IP}" != "x" ] && IPCFG=",\"EndpointConfig\":{\"IPAMConfig\":{\"IPv4Address\":\"${IP}\"}}"
         if [ "x${IP6}" != "x" ]; then
          [ "x${IP}" != "x" ] && IPCFG=",\"EndpointConfig\":{\"IPAMConfig\":{\"IPv4Address\":\"${IP}\",\"IPv6Address\":\"${IP6}\"}}"
         else
          IPCFG=",\"EndpointConfig\":{\"IPAMConfig\":{\"IPv6Address\":\"${IP6}\"}}"
         fi
         echo "$(data) Connecting in network [${NET}:${IP}]"
         $CURL -H "$HEADER" -d '{"Container":"'${ID}'"'${IPCFG}'}' -X POST ${URL_NT}/${NET}/connect
        done
        $CURL -X POST ${URL_CT}/${ID}/start
       else
        echo $(data)" $IMGCMD - IP: [$IP_USED] is already allocated!!!"
       fi
       sleep 5
      fi
     #else
     # echo "Same configuration detect on Master"
     fi
    fi
   done
   sleep 30
  done
 fi
fi
