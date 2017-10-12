#!/bin/bash
# Backup vision resoruces
# 1. Mongodb - /opt/backups/mongodb
# 2. Images  - /opt/backups/data

# Default backups are disabled - enabled in props file
# Default BACKUP_MODE LOCAL - backups stored in a local file system
# Location can be configure in a props file

# Global variables

BACKUP_MODE=LOCAL
BACKUP_DB_ENABLED=FALSE
BACKUP_IMAGES_ENABLED=FALSE
BACKUP_ROOT="/opt/backups"
BACKUP_HOME=$BACKUP_ROOT/bin
BACKUP_CONFIG_FILE=$BACKUP_HOME/props
BACKUP_LOCATION="/opt/backups"
KEEP_LOCAL_COPY="TRUE"

DATA_SOURCE_FOLDER="/opt/tomcat/webapps/data/"


MONGODB_DATABASE="vision_local"
MONGODB_USER="sgs"
MONGODB_PASSWORD="RF1Dkings"
MONGODB_HOST="localhost"
MONGODB_PORT="27017"

SFTP_USER=""
SFTP_HOST=""
SFTP_TARGET=""

cleanup_remote() {
echo "Cleanup remote file->"
sftp $1@$2 >>$BACKUP_ROOT_LOGS/remote.logs <<EOF
cd $3
rm $4 
bye
EOF
echo "<-Cleanup remote file"
}

#####################################
# File transfer - 
# Requires pre authentication setup
# Ref : key setup doc
#####################################
file_transfer(){
	echo "SFTP file->"
	USER=$SFTP_USER   #admin
	SFTP_SERVER=$SFTP_HOST   #192.168.4.19
	TARGET_BACKUP_LOCATION=$SFTP_TARGET  #"/opt/backups/backup_192_168_5_10/"
	SOURCE_FILE=$1
	
sftp $USER@$SFTP_SERVER >>$BACKUP_ROOT_LOGS/remote.logs <<EOF
cd $TARGET_BACKUP_LOCATION
put $SOURCE_FILE
bye
EOF
rc=$?
	if [ $rc -ne 0 ]; then
	 cleanup_remote $USER $SFTP_SERVER $TARGET_BACKUP_LOCATION $SOURCE_FILE
	 return 1
	else
	 return 0
	fi
	echo "<-SFTP file"
}
#####################################
#  Mongodb backup
#####################################
mongodb_backup(){
	### Set server settings
	HOST=$MONGODB_HOST
	PORT=$MONGODB_PORT # default mongoDb port is 27017
	USERNAME=$MONGODB_USER
	PASSWORD=$MONGODB_PASSWORD
	DATABASE=$MONGODB_DATABASE
	
	CURRENT_DAY=`date +%y%m%d%H%M%S`
	BACKUP_MONGODB_PATH_CURRENT_DAY=$BACKUP_MONGODB_PATH/$CURRENT_DAY
	
	mkdir -p $BACKUP_MONGODB_PATH_CURRENT_DAY
	
	mongodump -h $HOST -d $DATABASE -u $USERNAME -p $PASSWORD -o $BACKUP_MONGODB_PATH_CURRENT_DAY
	
	cd $BACKUP_MONGODB_PATH
	
	TAR_FILE=$CURRENT_DAY.mongodb.tar.gz
	
	tar -zcvf $TAR_FILE $CURRENT_DAY
	rm -r $CURRENT_DAY
	
	if [ "$BACKUP_MODE" = "REMOTE" ]; then
	   file_transfer $BACKUP_MONGODB_PATH/$TAR_FILE
	   ret=$?
	   if [ $ret == 0 ]; then
	   	  if [ "$KEEP_LOCAL_COPY" != "TRUE" ]; then
	   	  		rm $BACKUP_MONGODB_PATH/$TAR_FILE
	   	  fi
	   fi
	fi

}

data_backup() {


	CURRENT_DAY=`date +%y%m%d%H%M%S`
	mkdir $BACKUP_DATA_PATH/$CURRENT_DAY

	BACKUP_DATA_PATH_CURRENT_DAY=$BACKUP_DATA_PATH/$CURRENT_DAY
	
	echo "$DATA_SOURCE_FOLDER"
	echo "$BACKUP_DATA_PATH_CURRENT_DAY"
	
	cp -R $DATA_SOURCE_FOLDER $BACKUP_DATA_PATH_CURRENT_DAY
	
	cd $BACKUP_DATA_PATH
	TAR_FILE=$CURRENT_DAY.data.tar.gz
	tar -zcvf $TAR_FILE $CURRENT_DAY
	rm -r $CURRENT_DAY
	if [ "$BACKUP_MODE" = "REMOTE" ]; then
	file_transfer $BACKUP_DATA_PATH/$TAR_FILE
	   ret=$?
		if [ "$KEEP_LOCAL_COPY" != "TRUE" ]; then
			rm $BACKUP_MONGODB_PATH/$TAR_FILE
		fi
	fi
}

initialize() {
	if [ -z "$BACKUP_LOCATION" ];then
		BACKUP_LOCATION=BACKUP_ROOT
	fi
	
	BACKUP_MONGODB_PATH=$BACKUP_LOCATION/mongodb
	if [ ! -d $BACKUP_MONGODB_PATH ]; then
	 	mkdir -p $BACKUP_MONGODB_PATH
	fi
	
	BACKUP_DATA_PATH=$BACKUP_LOCATION/data
	if [ ! -d $BACKUP_DATA_PATH ]; then
		mkdir -p $BACKUP_DATA_PATH
	fi
	
	BACKUP_DATE_LOGS=$BACKUP_LOCATION/logs
	if [ ! -d $BACKUP_DATE_LOGS ]; then
		mkdir $BACKUP_DATE_LOGS
	fi	
	
}


# Run user root
if [[ $(id -u) -ne 0 ]] ; then 
	echo "Please run as root" ; 
	exit 1 ; 
fi

# check configuration props exits under the run directory /opt/backups/bin/
if [ ! -f "$BACKUP_CONFIG_FILE" ]; then
	echo "Configuration file missing.."
	exit 0
fi

while IFS=" " read -r key value
do
	if [ "$key" = "BACKUP_IMAGES_ENABLED" ]; then
		BACKUP_IMAGES_ENABLED="$value"
	fi
	if [ "$key" = "BACKUP_DB_ENABLED" ]; then
		BACKUP_DB_ENABLED="$value"
	fi
	if [ "$key" = "BACKUP_LOCATION" ]; then
		BACKUP_LOCATION="$value"
	fi
	if [ "$key" = "BACKUP_MODE" ]; then
		BACKUP_MODE="$value"
	fi
	if [ "$key" = "MONGODB_USER" ]; then
		MONGODB_USER="$value"
	fi
	if [ "$key" = "MONGODB_PASSWORD" ]; then
	  MONGODB_PASSWORD="$value"
	fi
	if [ "$key" = "MONGODB_HOST" ]; then
	  MONGODB_HOST="$value"
	fi	
	if [ "$key" = "MONGODB_PORT" ]; then
	  MONGODB_PORT="$value"
	fi
	if [ "$key" = "MONGODB_DATABASE" ]; then
	  MONGODB_DATABASE="$value"
	fi
	if [ "$key" = "DATA_SOURCE_FOLDER" ]; then
	  DATA_SOURCE_FOLDER="$value"
	fi
	if [ "$key" = "KEEP_LOCAL_COPY" ]; then
	  KEEP_LOCAL_COPY="$value"
	fi	
	if [ "$key" = "KEEP_LOCAL_COPY" ]; then
	  KEEP_LOCAL_COPY="$value"
	fi
	if [ "$key" = "SFTP_USER" ]; then
	  SFTP_USER="$value"
	fi
	if [ "$key" = "SFTP_HOST" ]; then
	  SFTP_HOST="$value"
	fi
	if [ "$key" = "SFTP_TARGET" ]; then
	  SFTP_TARGET="$value"
	fi
	echo "$key $value" 
done < "$BACKUP_CONFIG_FILE"

if [ "$BACKUP_DB_ENABLED" != "TRUE" ]; then
    if [ "$BACKUP_IMAGES_ENABLED" != "TRUE" ]; then
		echo "Backup not enabled"
		exit 0    	 
    fi
fi

initialize
if [ "$BACKUP_DB_ENABLED" == "TRUE" ]; then
	mongodb_backup
fi
if [ "$BACKUP_IMAGES_ENABLED" == "TRUE" ]; then
	data_backup
fi

