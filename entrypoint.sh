#!/bin/sh
#VERSION:0.2.0
CFG="/docker-manager.cfg"
CFG_TMP="/tmp/.docker-manager.cfg"
URL_CT="http:/docker/containers"
URL_NT="http:/docker/networks"
URL_IMG="http:/docker/images"
DOCKER_SOCK="/var/run/docker.sock"
CURL="curl -s --unix-socket ${DOCKER_SOCK}"
HEADER="Content-Type: application/json"
TIME_GC_CHECK=5
TIME_GC_SHUTDOWN=20
TIME_MODE_RUN=3600
LOG_DIR=/var/log/docker-manager
NANOCPUS_X=1000000000
AUTOREMOVE='"autoremove":true'

function f_date {
 date "+%Y-%m-%d-%H%M%S"
}
function f_echo {
 echo "$(f_date) $1"
 [ "$2" != "" ] && echo "$(f_date) $1" >> $LOG_DIR/$2.log
 [ "$2" != "master" ] && echo "$(f_date) [GC] $1" >> $LOG_DIR/master.log
}

function f_log {
 LOG_ARGS='logs?stderr=1&stdout=1&follow=1&tail=1'
 CURL_LOG='curl --no-buffer -s -XGET --unix-socket '${DOCKER_SOCK}
 LOG_SH=/tmp/log-$1.sh
 echo '#!/bin/sh' > $LOG_SH
 #https://github.com/willfarrell/docker-filebeat/blob/782f66b2117e1627b25fc3343557c2b4525b725b/5-stdin/docker-entrypoint.sh#L18
 #echo ${CURL_LOG}' "'${URL_CT}'/'$1'/'${LOG_ARGS}'" | tr -d '"'\000'"' | sed "s;^[^[:print:]];$(date "+%Y-%m-%d-%H%M%S:") [SL] ;" > '$LOG_DIR/$2.log > $LOG_SH
 echo ${CURL_LOG}' "'${URL_CT}'/'$1'/'${LOG_ARGS}'" | tr -d '"'\000'"' | sed "s;^[^[:print:]];$(date "+%Y-%m-%d-%H%M%S:") ;" > '$LOG_DIR/$2.log > $LOG_SH
 echo 'echo "$(date "+%Y-%m-%d-%H%M%S:") Container down" > '$LOG_DIR/$2.log >> $LOG_SH
 chmod +x $LOG_SH
 $LOG_SH &
}

function f_populate_cfg_tmp {
rm -rf $CFG_TMP
NLINE=""
for I in $(seq $(cat $CFG|wc -l)); do
 LINE=$(head -$I $CFG|tail -1|grep -v ^#)
 if [ "$LINE" != "" ]; then
  if [ "x$(echo "${LINE: -1}")" != "x\\" ]; then
   echo ${NLINE}${LINE} >> $CFG_TMP
   NLINE=""
  else
   CUT=$((${#LINE}-1))
   LINE=$(echo "${LINE:0:$CUT}")' '
   NLINE=${NLINE}${LINE}
  fi
 fi
done
}

function docker_manager_gc_start {
 f_echo "Starting docker-manager-gc" master
 GC_ERROR=""
 BINDS=""
 MNG_IMG=$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Image')
 if [ "${MNG_IMG}" != "" ]; then
  MASTER_ID_CUT=$(echo ${MASTER_ID}|cut -c1-12)
  CREATE_GC="create?name=${MASTER_NAME}.gc.${MASTER_ID_CUT}"
  DOCKER_SOCK_MASTER=$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Mounts[]|select(.Destination=="'${DOCKER_SOCK}'")|.Source')
  LOG_MASTER=$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Mounts[]|select(.Destination=="'${LOG_DIR}'")|.Source')
  BINDS=',"Binds":["'${DOCKER_SOCK_MASTER}':'${DOCKER_SOCK}'"]'
  [ "${LOG_MASTER}" != "" ] && BINDS=${BINDS/]/,\"$LOG_MASTER:$LOG_DIR\"]}
  #echo $BINDS
  GC_CMD='"Cmd":["--docker-manager-gc","'${MASTER_ID}'"]'
  GC_ID=$($CURL -H "$HEADER" -d '{"Image":"'${MNG_IMG}'",'${GC_CMD}',"Labels":{"docker.manager.gc.master":"'${MASTER_ID}'","docker.manager.master.server":"false"}'${BINDS}','${AUTOREMOVE}'}' -X POST ${URL_CT}/${CREATE_GC})
  f_echo "$GC_ID" master
  GC_ID=$(echo $GC_ID|jq -r .Id)
  [ "${GC_ID}" != "" ] && $CURL -X POST ${URL_CT}/${GC_ID}/start || GC_ERROR="ERROR: Could not create container Docker-Manager-gc"
  sleep 5
  [ "${GC_ERROR}" = "" ] && GC_ERROR=$( [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${GC_ID}'"))|map(select(.State=="running"))[]|.Id')" = "" ] && echo "Docker-Manager-gc can not be started")
 else
    GC_ERROR="ERROR: Any Docker-Manager image found"
 fi
 if [ "${GC_ERROR}" != "" ]; then
  f_echo "$GC_ERROR" master
  f_echo "Shutdown in ${TIME_GC_SHUTDOWN}s" master
  sleep $TIME_GC_SHUTDOWN
  exit 1
 else
  f_echo "Docker-Manager-gc initialized [$MNG_IMG --docker-manager-gc ${MASTER_ID}]" master
 fi
}

if [ ! -e ${DOCKER_SOCK} ]; then
 f_echo "Docker Sock: [${DOCKER_SOCK}] not found. Try docker run -d -v /var/run/docker.sock:/var/run/docker.sock riav/docker-manager" master
else
 #MODE RUN
 [ "$1" = "--mode-run" ] && while true; do f_echo "Mode run enabled" mode-run; sleep $TIME_MODE_RUN; done
 #MODE GARBAGE COLLECTOR
 if [ "$1" = "--docker-manager-gc" ]; then
  if [ "$2" = "" ]; then
   f_echo "ERROR: No parameter Master Docker-Manager id" gc
  else
   EXIT=0
   MASTER_ID=$2
   #Check if masterid is valid
   if [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))|map(select(.Labels."docker.manager.master.server"=="true"))[]|.Id')" = "" ]; then
    f_echo "ERROR: Id parameter does not belong to a Master." gc
    EXIT=1
   else
    f_echo "Garbabe Collector is up..." gc
   fi
   f_echo "Docker-Manager-gc - Master id: ${MASTER_ID}" gc
   while [ ${EXIT} -eq 0 ]; do
    sleep $TIME_GC_CHECK
    if [ "$($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Id=="'${MASTER_ID}'"))|map(select(.State=="running"))[]|.Id')" = "" ]; then
     f_echo "Docker-Manager is not present at the host. shutdown slave containers" gc
     for SLAVE_ID in $($CURL -X GET ${URL_CT}/json|jq -r 'map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id'); do
      #f_echo "Killing Slave Container id (${SLAVE_ID})" gc
      #$CURL -X POST ${URL_CT}/${SLAVE_ID}/kill
      f_echo "Removing Slave Container id (${SLAVE_ID})" gc
      $CURL -X DELETE ${URL_CT}/${SLAVE_ID}?force=true
      sleep 1
     done
     EXIT=1
     f_echo "Shutdown myself..." gc
    fi
   done
  fi
 else
  MASTER_ID=""
  MASTER_HN="$(hostname)"
  for ID in $($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.master.server"=="true"))[]|.Id'); do
   [ "$(echo $ID|cut -c1-12|grep $MASTER_HN)" != "" ] && MASTER_ID=$ID
  done
  MASTER_NAME=$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Id=="'${MASTER_ID}'"))[]|.Names[]'|cut -d'.' -f1)
  MASTER_NAME=${MASTER_NAME//\//}
  f_echo " SOCK: ${DOCKER_SOCK}" master
  f_echo " Awaiting cleaning of slaves containers" master
  sleep 15
  #f_echo "Master: ${MASTER_NAME}:${MASTER_ID}" master
  while true; do
   #Iniciando docker-manager-gc
   [ "$($CURL ${URL_CT}/json|jq -r 'map(select(.Labels."docker.manager.master.server"=="false"))|map(select(.Labels."docker.manager.gc.master"=="'${MASTER_ID}'"))[]|.Id')" = "" ] && docker_manager_gc_start
   #
   #cat $CFG|grep -v ^# > ${CFG_TMP}
   #Populate ${CFG_TMP}
   f_populate_cfg_tmp
   if [ $(cat $CFG_TMP|wc -l) -eq 0 ]; then
    f_echo "No entries found in $CFG_TMP" master
    f_echo "Exiting" master
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
      ID_RM=$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.slave.cfg"=="'${SLAVE}'"))|map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id')
      if [ "${ID_RM}" != "" ]; then
       f_echo "Removing slave container $ID_RM" master
       #$CURL -X POST ${URL_CT}/${ID_RM}/kill
       $CURL -X DELETE ${URL_CT}/${ID_RM}?force=true
       sleep 1
      fi
     fi
    done
   fi
   for I in $(seq $(cat ${CFG_TMP}|wc -l)); do
    CREATE="create"; OPT=""; ENV=""; VOL=""; IPS6=""; IPS=""; NETS=""; HTCONF=""; HTNAME=""; NAME=""; NTWK=""; POS=-1; CFG_HASH=""; IMGCMD=""; LABELS=""
    ENTRYPOINT=""; STG_OPT="" RESTART_POL=$AUTOREMOVE
    CFG_HASH=$(head -$I $CFG_TMP|tail -1|md5sum|awk '{print $1}')
    if [ "$CFG_HASH" != "d41d8cd98f00b204e9800998ecf8427e" ]; then
     if [ "x$($CURL -X GET ${URL_CT}/json?all=1|jq -r 'map(select(.Labels."docker.manager.slave.cfg"=="'$CFG_HASH'"))|map(select(.Labels."docker.manager.slave.master"=="'${MASTER_ID}'"))[]|.Id')" = "x" ]; then
      for VALUE in $(head -$I $CFG_TMP|tail -1|grep -v ^#); do
       NOPT=0
       case $OPT in
        'VOL') VOL=$VOL'"'$VALUE'",'; OPT="";;
        'IP') IPS="${IPS}#${POS}#${VALUE} "; OPT="";;
        'IP6') IPS6="${IPS6}#${POS}#${VALUE} "; OPT="";;
        'MAC') MACS="${MACS}#${POS}#${VALUE} "; OPT="";;
        'NET') NETS="${NETS}#${POS}#${VALUE} "; OPT="";;
        'NAME') NAME=$VALUE; OPT="";;
        'HTNAME') HTNAME=$VALUE; OPT="";;
        'STG') STG_OPT=${STG_OPT}'"'${VALUE/=/\":\"}'",'; OPT="";;
        'ENV') ENV=$ENV'"'$VALUE'",'; OPT="";;
        'ETP') VALUE=${VALUE//,/ }; for ETP in $VALUE; do ENTRYPOINT=${ENTRYPOINT}'"'${ETP}'",'; done; OPT="";;
	'RESTART') RESTART_POL='"RestartPolicy":{"Name":"'${VALUE}'","MaximumRetryCount":0}'; OPT="";;
	'LBL') LBL_KEY=$(echo $VALUE|awk -F'=' '{print $1}'); LBL_VALUE=$(echo $VALUE|awk -F'=' '{print $2}'); LABELS=$LABELS',"'${LBL_KEY}'":"'${LBL_VALUE}'"'; OPT="";;
        'HTCONFBOO') HTCONF=${HTCONF}'"'${OPT_VALUE}'":true,'; OPT="";;
	'HTCONFBYTES') VALUE=$(echo $VALUE|tr [:upper:] [:lower:])
	 VALUE=${VALUE/b/ 1}; VALUE=${VALUE/k/ 1024}; VALUE=${VALUE/m/ 1048576}; VALUE=${VALUE/g/ 1073741824}
	 VALUE=${VALUE//,/.}; VALUE=$(echo "$VALUE"|awk '{print $1*$2}')
	 HTCONF=${HTCONF}'"'${OPT_VALUE}'":'${VALUE}','; OPT="";;
	'HTCONFINT') STR=""; case "$OPT_VALUE" in cpuset*) STR='"';; 'nanocpus') VALUE=${VALUE//,/.}; VALUE=$(echo "$VALUE $NANOCPUS_X"|awk '{print $1*$2}');; esac
	 HTCONF=${HTCONF}'"'${OPT_VALUE}'":'${STR}${VALUE}${STR}','; OPT="";;
        *) NOPT=1;;
       esac
       [ "$VALUE" = "-c" ] && VALUE="--cpu-shares"
       [ "$VALUE" = "-m" ] && VALUE="--memory"
       case $VALUE in
        '-v'|'--volume') OPT="VOL";;
        '--ip') OPT="IP";;
        '--ip6') OPT="IP6";;
        '--mac-address') OPT="MAC";;
        '--net'|'--network') OPT="NET"; POS=$(($POS+1));;
        '--name') OPT="NAME";;
        '--hostname') OPT="HTNAME";;
        '--restart') OPT="RESTART";;
        '-e'|'--env') OPT="ENV";;
        '--label'|'-l') OPT="LBL";;
        '--entrypoint') OPT="ETP";;
        '--storage-opt') OPT="STG";;
        *-memory*|'--shm-size') [ "${VALUE}" = "--memory-swappiness" ] && OPT="HTCONFINT" || OPT="HTCONFBYTES"; OPT_VALUE=${VALUE//-/};;
        '--oom-score-adj'|'--pids-limit') OPT="HTCONFINT"; OPT_VALUE=${VALUE//-/};;
        --cpu*) OPT="HTCONFINT"; OPT_VALUE=${VALUE//-rt-/realtime}; OPT_VALUE=${VALUE//-/}; [ "$OPT_VALUE" = "cpus" ] && OPT_VALUE="nanocpus";;
        '--privileged'|'--oom-kill-disable'|'--network-disabled') OPT="HTCONFBOO"; OPT_VALUE=${VALUE//-/};;
        '--read-only') OPT="HTCONFBOO"; OPT_VALUE="ReadonlyRootfs";;
        *) [ $NOPT -eq 1 ] && IMGCMD="${IMGCMD}${VALUE} ";;
       esac
      done
      #echo "N: ${NETS} - I: ${IPS}"
      if [ "x$NAME" != "x" ]; then
       #HTNAME="\"Hostname\":\"${MASTER_NAME}.${NAME}\","
       #CREATE="${CREATE}?name=${MASTER_NAME}.${NAME}"
       NAME="slave.${NAME}.${CFG_HASH}"
      else
      # #HTNAME="\"Hostname\":\"${MASTER_NAME}.${MASTER_ID}\","
      # CREATE="${CREATE}?name=${MASTER_NAME}.${NAME}"
       NAME="slave.$CFG_HASH"
      fi
      [ "x$HTNAME" != "x" ] && HTNAME='"Hostname":"'${HTNAME}'",'
      SLAVE_NAME="${MASTER_NAME}.${NAME}"
      CREATE="${CREATE}?name=${SLAVE_NAME}"
      NET=$(echo $NETS|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
      if [ "$NET" != "" ]; then
       IP=$(echo $IPS|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
       IP6=$(echo $IPS6|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
       MAC=$(echo $MACS|awk '{print $1}'|grep '#0#'|awk -F'#' '{print $3}')
       [ "${IP6}" != "" ] && IP6=',"IPv6Address":"'${IP6}'"'
       [ "${MAC}" != "" ] && MAC=',"MacAddress":"'${MAC}'"'
       NTWK=',"NetworkingConfig":{"EndpointsConfig":{"'${NET}'":{"IPAMConfig":{"IPv4Address":"'${IP}'"'${IP6}'}'${MAC}'}}}'
      fi
      if [ "x$STG_OPT" != "x" ]; then
       STG_OPT=${STG_OPT%,}
       HTCONF=${HTCONF}'"StorageOpt":{'${STG_OPT}'},'
      fi
      if [ "x$ENTRYPOINT" != "x" ]; then
       ENTRYPOINT=${ENTRYPOINT%,}
       ENTRYPOINT=',"Entrypoint":['$ENTRYPOINT']'
      fi
      if [ "x$VOL" != "x" ]; then
       VOL=${VOL%,}
       VOL=',"Binds":['$VOL']'
      fi
      IMG=""; CMD=""; FIMG=""
      for VAL in $IMGCMD; do
       if [ "x$FIMG" = "x" ]; then
        IMG='"Image":"'$VAL'"'
        FIMG=$VAL
       else
        CMD=$CMD'"'$VAL'",'
       fi
      done
      if [ "x$FIMG" = "x" ]; then
       f_echo "No Imagem found on $CFG in configuration $(head -$I $CFG_TMP|tail -1)" master
      else
       IMGCMD=$IMG
       if [ "x$CMD" != "x" ]; then
        CMD=${CMD%,}
        IMGCMD=$IMG',"Cmd":['$CMD']'
       fi
       IMGCMD=${IMGCMD}${ENTRYPOINT}
       if [ "x$ENV" != "x" ]; then
        ENV=${ENV%,}
        ENV=',"Env":['$ENV']'
       fi
       f_echo "Geting Image ${FIMG}" master
       $CURL -X POST ${URL_IMG}/create?fromImage=${FIMG}|jq -r .status
       IP_USED=""
       for IP_ in $IPS; do
        IP=$(echo ${IP_}|awk -F'#' '{print $3}')
        [ "x$($CURL ${URL_CT}/json?all=1|jq .[].NetworkSettings|grep -i '"ip.*Address'|grep '"'${IP}'"')" != "x" ] && IP_USED=${IP}
       done
       if [ "x${IP_USED}" = "x" ]; then
        ID=$($CURL -H "$HEADER" -d '{'${HTNAME}${IMGCMD}',"Labels":{"docker.manager.slave.master":"'${MASTER_ID}'","docker.manager.slave.cfg":"'${CFG_HASH}'"'${LABELS}'}'${ENV}${VOL}','${HTCONF}${RESTART_POL}${NTWK}'}' -X POST ${URL_CT}/${CREATE})
        f_echo "Create container: $ID" master
        ID=$(echo $ID|jq -r .Id)
        f_echo '{'${HTNAME}${IMGCMD}',"Labels":{"docker.manager.slave.master":"'${MASTER_ID}'","docker.manager.slave.cfg":"'${CFG_HASH}'"'${LABELS}'}'${ENV}${VOL}','${HTCONF}${RESTART_POL}${NTWK}'}' master
        IP=""; for IP_ in $IPS; do IP="${IP}$(echo $IP_|awk '{print $1}'|grep -v '#0#') "; done; IPS=$IP
        IP6=""; for IP6_ in $IPS6; do IP6="${IP6}$(echo $IP6_|awk '{print $1}'|grep -v '#0#') "; done; IPS6=$IP6
        MAC=""; for MAC_ in $MACS; do MAC="${MAC}$(echo $MAC_|awk '{print $1}'|grep -v '#0#') "; done; MACS=$MAC
        NET=""; for NET_ in $NETS; do NET="${NET}$(echo $NET_|awk '{print $1}'|grep -v '#0#') "; done; NETS=$NET
        #Z=1
        IPCFG=""
        for NET_ in $NETS; do
         NET=$(echo $NET_|awk -F'#' '{print $3}')
         POS=$(echo $NET_|awk -F'#' '{print $2}')
         IP=$(echo $IPS|grep -o '#'${POS}'#.*'|awk '{print $1}'|awk -F'#' '{print $3}')
         IP6=$(echo $IPS6|grep -o '#'${POS}'#.*'|awk '{print $1}'|awk -F'#' '{print $3}')
         MAC=$(echo $MACS|grep -o '#'${POS}'#.*'|awk '{print $1}'|awk -F'#' '{print $3}')
	 #MACCFG=""
	 #[ "${MAC}" != "" ] && MACCGF=',"MacAddress":"'${MAC}'"'
         #[ "${IP}" != "" ] && IPCFG=',"EndpointConfig":{"IPAMConfig":{"IPv4Address":"'${IP}'"}'${MACCFG}'}'
         #if [ "${IP6}" != "" ]; then
         # if [ "${IP}" != "" ]; then
	 #  IPCFG=',"EndpointConfig":{"IPAMConfig":{"IPv4Address":"'${IP}'","IPv6Address":"'${IP6}'"}'${MACCFG}'}'
         # else
         #  IPCFG=',"EndpointConfig":{"IPAMConfig":{"IPv6Address":"'${IP6}'"}'${MACCFG}'}'
	 # fi
         #fi       
	 [ "${IP6}" != "" ] && IP6=',"IPv6Address":"'${IP6}'"'
         [ "${MAC}" != "" ] && MAC=',"MacAddress":"'${MAC}'"'
         IPCFG=',"EndpointsConfig":{"'${NET}'":{"IPAMConfig":{"IPv4Address":"'${IP}'"'${IP6}'}'${MAC}'}}'
         f_echo "Connecting in network [${NET}:${IP}]" master
         $CURL -H "$HEADER" -d '{"Container":"'${ID}'"'${IPCFG}'}' -X POST ${URL_NT}/${NET}/connect
        done
        $CURL -X POST ${URL_CT}/${ID}/start
	f_log ${ID} ${SLAVE_NAME}
       else
        f_echo "$IMGCMD - IP: [$IP_USED] is already allocated" master
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
