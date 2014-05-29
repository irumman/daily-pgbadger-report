#!/bin/bash



OPTION_FILE=/home/ahmad.iftekhar/pgbadger/options.conf
SERVERS_FILE=/home/ahmad.iftekhar/pgbadger/servers.conf

DBHOST_SSH_USER=postgres
PGBADGER_HOST_SSH_USER=postgres
TMP_LOG_DIR=/home/ahmad.iftekhar/pgbadger/pg_log
TMP_HTML_DIR=/home/ahmad.iftekhar/pgbadger/html
PGBADGER_ENGINE="perl /home/ahmad.iftekhar/pgbadger/lib/pgbadger"
TMP_COMMAND_FILE=.tmp_command
HTMLFILE=''
DEBUG=1
RETURN=1
REMOTE_COPY=scp
REMOTE_LOGIN=ssh

DT="2014-05-25"

WEBSERVER_REHOST=127.0.0.1
WEBSERVER_REUSER=ahmad.iftekhar
WEBSERVER_DIR=/home/ahmad.iftekhar/pgbadger/webserver_tmp



#log_filename=postgresql-%Y-%m-%d_%H%M%S.log

debug_log () {
  if [ $DEBUG -eq 1 ];
  then
     echo -e  "DEBUG: $1"
  fi
}

exit_with_error () {
  echo -e "!!!CRITICAL!!! $1 "
  exit 1
}






import_log_files () {
   
   pushd   $TMP_LOG_DIR/${HOST_ADDR}
   debug_log "${REMOTE_COPY} ${DBHOST_SSH_USER}@${HOST_ADDR}:${PG_LOG_DIR}/${LOG_FILE_NAME} $TMP_LOG_DIR/${HOST_ADDR}/"
   ${REMOTE_COPY} ${DBHOST_SSH_USER}@${HOST_ADDR}:${PG_LOG_DIR}/${LOG_FILE_NAME} ${TMP_LOG_DIR}/${HOST_ADDR}/
   if [ $? -ne 0 ];
   then   
      echo -e "!!CRITICAL!! Failed to get ${HOST_ADDR}:${PG_LOG_DIR}/${LOG_FILE_NAME}"
      RETURN=0
   fi   
   RETURN=1
}

generate_html () {
  
  OUTPUT_FILE_NAME=${HOST_ADDR}_${DT}_${PGBADGER_OPTION}
  debug_log "RAW OUTPUT_FILE_NAME=${OUTPUT_FILE_NAME}"
  OUTPUT_FILE_NAME=`echo ${OUTPUT_FILE_NAME} | sed -r 's/[^[:alnum:]]/_/g'  `
  OUTPUT_FILE_NAME=${OUTPUT_FILE_NAME}.html
  debug_log "OUTPUT_FILE_NAME=${OUTPUT_FILE_NAME}"
  
  OUTPUT_DIR=${TMP_HTML_DIR}/${HOST_ADDR}
  debug_log "OUTPUT_DIR=${OUTPUT_DIR}"
  
  NUMBER_OF_LOG_FILES=`ls -l $TMP_LOG_DIR/${HOST_ADDR}/postgresql-${DT}*.log | wc -l`
  debug_log "NUMBER_OF_LOG_FILES=${NUMBER_OF_LOG_FILES}"
  debug_log "$PGBADGER_ENGINE -o ${OUTPUT_FILE_NAME} -O ${OUTPUT_DIR}  $TMP_LOG_DIR/${HOST_ADDR}/postgresql-${DT}*.log ${PGBADGER_OPTION_DETAIL} " 
  
  HOST_TMP_COMMAND_FILE="${TMP_COMMAND_FILE}"."${HOST_ADDR}" 
  echo  "$PGBADGER_ENGINE -o ${OUTPUT_FILE_NAME} -O ${OUTPUT_DIR}   $TMP_LOG_DIR/${HOST_ADDR}/postgresql-${DT}*.log ${PGBADGER_OPTION_DETAIL}" >  "$HOST_TMP_COMMAND_FILE"
  
  sh ${HOST_TMP_COMMAND_FILE}
  rm ${HOST_TMP_COMMAND_FILE}
  HTMLFILE=${OUTPUT_DIR}/${OUTPUT_FILE_NAME}  
   
  debug_log "Cleaup postgresql logs"   
  debug_log "rm -f $TMP_LOG_DIR/${HOST_ADDR}/postgresql-${DT}*.log"
  rm -f $TMP_LOG_DIR/${HOST_ADDR}/postgresql-${DT}*.log
}


push_html_files_in_web () {
     
  ${REMOTE_COPY} ${HTMLFILE}  ${WEBSERVER_REUSER}@${WEBSERVER_REHOST}:${WEBSERVER_DIR}
   if [ $? -ne 0 ];
   then   
      echo -e "!!CRITICAL!! Failed to get ${HOST_ADDR}:${PG_LOG_DIR}/${LOG_FILE_NAME}"
      RETURN=0
   fi   
   RETURN=1
}


cleanup_html_files () {
  REMOTE_COMMAND="\"find ${WEBSERVER_DIR}/* -mtime  ${HTML_RETENTION} -exec  rm {} \;\" " 
  cmd="${REMOTE_LOGIN} ${WEBSERVER_REUSER}@${WEBSERVER_REHOST}  ${REMOTE_COMMAND}" 
  debug_log "$cmd"
  HOST_TMP_COMMAND_FILE="${TMP_COMMAND_FILE}"."${HOST_ADDR}" 
  echo "$cmd" > ${HOST_TMP_COMMAND_FILE}
  sh ${HOST_TMP_COMMAND_FILE}
  rm ${HOST_TMP_COMMAND_FILE}
  if [ $? -ne 0 ];
  then   
      echo -e "!!CRITICAL!! Failed to cleanup html files for  ${HOST_ADDR}"
      RETURN=0
   fi   
   RETURN=1
}




create_directory () {
   DIR_NAME=${1}
   if [ -d ${DIR_NAME} ];
   then
     debug_log "Directory exists ${DIR_NAME}"
   else  
	   mkdir -p ${DIR_NAME}
	   if [ $? = 0 ];
	   then
	   		debug_log "Directory created $TMP_LOG_DIR/${HOST_ADDR}"
	   else
	    	echo -e "!!CRITICAL!! Can't create the directory ${DIR_NAME}"
	    	RETURN=0
	   fi 
   fi
   RETURN=1
}




if [ -z ${DT} ];
then
	DT=`date --date="-1 day" +'%F'` #2014-05-27
fi
LOG_FILE_NAME=postgresql-${DT}*.log	
debug_log "LOG_FILE_NAME=${LOG_FILE_NAME}"


cat $SERVERS_FILE | while read each_server
do
   RETURN=1
   debug_log "\nLine read= $each_server"
   first_char=`echo $each_server | awk '{print substr($0,1,1);exit}'`
   debug_log "first_char=$first_char"
   if [ ${first_char} == "#" ];
   then
      debug_log "Commented line" 
      continue
   fi   
   
   HOST_ADDR=`echo $each_server | cut -d ':' -f1` 
   debug_log "HOST_ADDR=$HOST_ADDR"
   
   PG_LOG_DIR=`echo $each_server | cut -d ':' -f2` 
   debug_log "PG_LOG_DIR=$PG_LOG_DIR"
   
   PGBADGER_OPTION=`echo $each_server | cut -d ':' -f3`
   debug_log "PGBADGER_OPTION=$PGBADGER_OPTION"
   
   HTML_RETENTION=`echo $each_server | cut -d ':' -f4`
   debug_log "HTML_RETENTION=$HTML_RETENTION"
   
   PGBADGER_OPTION_DETAIL=`cat ${OPTION_FILE} | grep -i "${PGBADGER_OPTION}" | cut -d ':' -f 2-`
   debug_log "PGBADGER_OPTION_DETAIL=${PGBADGER_OPTION_DETAIL}"
   
   create_directory ${TMP_LOG_DIR}/${HOST_ADDR}
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi
     
   create_directory ${TMP_HTML_DIR}/${HOST_ADDR}
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi
   
   
   import_log_files 
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi

   generate_html 
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi
   
   push_html_files_in_web
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi
   
   cleanup_html_files
   if [ ${RETURN} -eq 0 ];
   then
     continue
   fi
   

done