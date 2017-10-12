#!/bin/bash
# Restore vision resoruces

# Global Variables
ARGS=""
VALUE=""
ENTER="Enter "
#####################################
# Read required arguments
#####################################
readvalue(){

	flag=1
	VALUE=""
	while [ $flag != 0 ]
	do
		echo "$ARGS "
		read param
		if [ -z "$param" ]; then
			flag=1
		else
			VALUE=$param
			flag=0
		fi
	done

}
#####################################
#  Mongodb backup
#####################################
mongodb_backup() {

	echo "mongodb_backup->"
	CURRENT_DAY=`date +%y%m%d%H%M%S`
	BACKUP_MONGODB_PATH_CURRENT_DAY=$6/$CURRENT_DAY
	mkdir -p $BACKUP_MONGODB_PATH_CURRENT_DAY
	
	#mongodump -h $HOST -d $DATABASE -u $USERNAME -p $PASSWORD -o $BACKUP_MONGODB_PATH_CURRENT_DAY
	mongodump --host $1 --port $2 --db $3 --username $4 --password $5 --out $BACKUP_MONGODB_PATH_CURRENT_DAY
	
	echo "Mongodb backup location $BACKUP_MONGODB_PATH_CURRENT_DAY."
	echo "<-mongodb_backup"
	
}
#####################################
# Restoring Mongodb 
#####################################
mongodb_restore_backup() {
	echo "mongodb_restore_backup->"
	#mongorestore --host $HOST --port $PORT --username $USERNAME --db vision_local --password $PASSWORD $RESTORE_PATH
	mongorestore --drop --host $1 --port $2 --db $3 --username $4 --password $5 $6
	if [ $? -ne 0 ]; then
	   echo "Mongodb restore failed... "
	fi
	echo "<-mongodb_restore_backup"
}

#####################################
# Stop Tomcat
#####################################
stop_tomcat() {
	echo "stop_tomcat->"
	service tomcat stop
	echo "stop tomcat process..."
	stopped=1
	running="running"
	count=0
	while [ $stopped != 0 ]
	do
	    ret=$(service tomcat status | grep running)
	    if [[ "$ret" =~ "$running" ]]; then
	        echo "waiting to stop tomcat..."
	        sleep 5
	        ((count++))
	        echo "$count"
	        stopped=1
	    else
	        echo "Tomcat stopped. Continue restore."
	        stopped=0
	    fi
	    if [ $count -gt 5 ]; then
	        echo "Timeout unable to stop in 25 seconds."
	    fi
	done
echo "<-stop_tomcat"
}

#####################################
# Stop Replenishment
#####################################
stop_replenishment() {
	echo "stop_replenishment->"
	sudo service replenishment stop
	echo "stop replenishment process..."
	stopped=1
	running="running"
	count=0
	while [ $stopped != 0 ]
	do
	    ret=$(sudo service replenishment status | grep running)
	    if [[ "$ret" =~ "$running" ]]; then
	        echo "waiting to stop replenishment..."
	        sleep 5
	        ((count++))
	        stopped=1
	    else
	        echo "Replenishment stopped. Continue restore."
	        stopped=0
	    fi
	    if [ $count -gt 5 ]; then
	        echo "Timeout unable to stop in 25 seconds."
	    fi
	done
	echo "<-stop_replenishment"
}

#####################################
# Start Tomcat
#####################################
start_tomcat() {
	echo "start_tomcat->"
	service tomcat start
	echo "start tomcat process..."
	started=1
	running="running"
	count=0
	while [ $started != 0 ]
	do
	    ret=$(service tomcat status | grep running)
	    if [[ "$ret" =~ "$running" ]]; then
	        echo "Tomcat started. Continue restore."
	        started=0
	    else
	        echo "waiting to start tomcat..."
	        sleep 5
	        ((count++))
	        echo "$count"
	        started=1
	    fi
	    if [ $count -gt 12 ]; then
	        echo "Timeout unable to start in 60 seconds..."
	    fi
	done
	echo "<-start_tomcat"
}
#####################################
# Start Replenishment
#####################################
start_replenishment() {
	echo "start_replenishment->"
	service replenishment start
	echo "start replenishment process..."
	started=1
	running="running"
	count=0
	while [ $started != 0 ]
	do
	    ret=$(service replenishment status | grep running)
	    if [[ "$ret" =~ "$running" ]]; then
	        echo "Replenishment started. Continue restore."
	        started=0
	    else
	        echo "waiting to start replenishment..."
	        sleep 5
	        ((count++))
	        echo "$count"
	        started=1
	    fi
	    if [ $count -gt 12 ]; then
	        echo "Timeout unable to start in 60 seconds..."
	    fi
	done
	echo "<-start_replenishment"
}
#####################################
# Restore Mongodb
#####################################
mongodb_restore(){

ARGS="$ENTER mongodb username !"
readvalue
if [ -z "$VALUE" ]; then
    echo "Invalid $ARGS $VALUE. "
    exit 0
fi
username=$VALUE

ARGS="$ENTER mongodb user $username password !" 
readvalue
if [ -z "$VALUE" ]; then
    echo "Invalid $ARGS $VALUE. "
    exit 0
fi
password=$VALUE

ARGS="$ENTER mongodb host !"
readvalue
if [ -z "$VALUE" ]; then
    echo "Invalid $ARGS $VALUE. "
    exit 0
fi
host=$VALUE


ARGS="$ENTER mongodb port !"
readvalue
if [ -z "$VALUE" ]; then
    echo "Invalid $ARGS $VALUE. "
exit 0
fi
port=$VALUE

ARGS="$ENTER mongodb database !"
readvalue
if [ -z "$VALUE" ]; then
    echo "Invalid $ARGS $VALUE. "
    exit 0
fi
database=$VALUE
backup_path="/tmp"
echo "---------------------------------------------"
echo "Verify parameters and confirm y(yes)/n(no) !"
echo "mongodb username = $username"
echo "password = $password"
echo "host = $host"
echo "database = $database"
echo "---------------------------------------------"
ARGS="Do you want to continue y (Yes) / n (No) ?"
readvalue
if [ "$VALUE" != "y" ]; then
   echo "Mongodb restore process stopped by the user. "
   exit 0
fi
ARGS="Re-confirm y (Yes) / n (No)  !"
readvalue
if [ "$VALUE" != "y" ]; then
   echo "Mongodb restore process stopped by the user. "
   exit 0
fi

#Verify backupd directory exits with database name
RESTORE_DB_DIR=$RESTORE_FILE/$database
echo "$RESTORE_DB_DIR"
if [ ! -d "$RESTORE_DB_DIR" ]; then
    echo "Restore directory is not matching with the database name"
    echo "Exit restore."
    exit 0
fi

echo "Backup database before restore: starts "
mongodb_backup $host $port $database $username $password $backup_path
echo "Backup database before restore: ends "

echo "Shutdown services: starts"
stop_tomcat
stop_replenishment
echo "Shutdown services: ends"

mongodb_restore_backup $host $port $database $username $password $RESTORE_DB_DIR

start_tomcat
start_replenishment
}
#####################################
# Restore resources 
#####################################
backup_images() {
	CURRENT_DAY=`date +%y%m%d%H%M%S`
	mkdir /tmp/$CURRENT_DAY
	cp -R $1 /tmp/$CURRENT_DAY
	echo "Backed up images before restore to /tmp/$CURRENT_DAY."
}

#####################################
# Restore resources 
#####################################
restore_images() {
	ARGS="Image target folder (enter y to use default /opt/tomcat/webapps/data ) !"
	readvalue
	if [ -z "$VALUE" ]; then
		echo "Invalid $ARGS $VALUE. "
		exit 0;
	fi
	if [ "$VALUE" = "y" ]; then
		VALUE="/opt/tomcat/webapps/data"
    fi
	target=$VALUE
	ARGS=" Do you want to continue y (Yes) / n (No) ?"
	readvalue
	if [ "$VALUE" != "y" ]; then
	   echo "Mongodb restore process stopped by the user. "
	   exit 0
	fi
	backup_images $target
	rc=$?
	if [ $rc -ne 0 ]; then
		echo "backup images failed, exit"
		exit 0;
	fi
	rm -R /opt/tomcat/webapps/data
	mv $RESTORE_FILE/data $target
	echo "Images restored"
}


#####################################
# Main 
#####################################
RESTORE_OPTION=$1
RESTORE_FILE=""

RESTORE_PATH=$2

if [[ $(id -u) -ne 0 ]] ; then 
	echo "Please run as root" ; 
	exit 1 ; 
fi

if [ "$RESTORE_OPTION" != "database" ] && [ "$RESTORE_OPTION" != "images" ]
then
    echo "Run from backup file directory [backup file path relative]." 
    echo "Usage /opt/backups/bin/restore <database or images> <171010141414.mongodb.tar.gz or 171010141414.data.tar.gz>"
    exit 0
fi
if [ "$RESTORE_OPTION" = "database" ]; then
    if [ ! -f $RESTORE_PATH ] && [ ! -d $RESTORE_PATH ]
    then
        echo "Restore resource not found $RESTORE_PATH"
        exit 0
    else

        if [ -f $RESTORE_PATH ]; then
            if [[ "$RESTORE_PATH" =~ ".mongodb.tar.gz" ]]; then
                RSTR=""
                RESTORE_FILE=${RESTORE_PATH/.mongodb.tar.gz/$RSTR}
                echo "Untar backup ...$RESTORE_FILE"
                tar xzf $RESTORE_PATH -C ./
                if [ $? -ne 0 ];then
                   echo "Untar file failed !"
                   exit 0;
                fi
            else
                echo "Corrupted or Invalid backup !"
                exit 0
            fi
        fi
        if [ -d "$RESTORE_PATH" ]; then
           RESTORE_FILE=$RESTORE_PATH
        fi
        mongodb_restore
    fi
fi

if [ "$RESTORE_OPTION" = "images" ]; then
    if [ ! -f $RESTORE_PATH ] && [ ! -d $RESTORE_PATH ]
    then
        echo "Restore resource not found $RESTORE_PATH"
        exit 0
    else
 		if [ -f $RESTORE_PATH ]; then
            if [[ "$RESTORE_PATH" =~ ".data.tar.gz" ]]; then
                RSTR=""
                RESTORE_FILE=${RESTORE_PATH/.data.tar.gz/$RSTR}
                echo "Untar backup ...$RESTORE_FILE"
                tar xzf $RESTORE_PATH -C ./
                if [ $? -ne 0 ];then
                   echo "Untar file failed !"
                   exit 0;
                fi
            else
                echo "Corrupted or Invalid backup !"
                exit 0
            fi
        fi
        if [ -d "$RESTORE_PATH" ]; then
           RESTORE_FILE=$RESTORE_PATH
        fi
        restore_images
    fi
fi