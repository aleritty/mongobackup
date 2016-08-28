#!/bin/bash

############à impostazioni da configurare ############
MONGO_HOST="localhost" ##xxx.xxx.xxx.xxx:PORT
MONGO_USE_AUTH="false"
MONGO_USER=""
MONGO_PW=""
MONGO_ONLY_DB="" #--db $MONGO_ONLY_DB
MONGO_ONLY_COLLECTION="" #-c $MONGO_ONLY_COLLECTION

BACKUP_PREFIX="mongodb-CDAT" #PLEASE NO SPACES

REMOVE_OLD_BACKUP="true"
KEEP_NUM="10"

REMOTE_BACKUP="true"
REMOTE_HOST="10.220.98.35"
REMOTE_USER="aleritty"
REMOTE_KEY="/home/aleritty/.ssh/id_rsa"
REMOTE_LOCATION="/home/aleritty/DBCDAT"


###INSTALLAZIONE CRONJOB (CON ESECUZIONE VIA BASH)
### Check cronjob
### Eliminazione cronjob


echo
echo '#### INIZIO BACKUP ####'
echo
TIMESTAMP=$(date +"%F_%H-%M") #Formato timestamp
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
###Controlla esistenza di mongodump senno chiedi ed installa
MONGODUMP_PATH="/usr/bin/mongodump"

if [ ! -d "$SCRIPT_DIR/DBbackup/" ]; then
  mkdir "$SCRIPT_DIR/DBbackup/"
fi
cd "$SCRIPT_DIR/DBbackup/"

$MONGODUMP_PATH --host $MONGO_HOST
#$MONGODUMP_PATH --host $MONGO_HOST -u $MONGO_USER -p $MONGO_PW
echo
echo '#### COMPRESSIONE DATI ####'
echo '#### può richiedere un po di tempo ####'
echo
tar -jcf "$BACKUP_PREFIX-$TIMESTAMP.tar.bz2" dump; rm -rf dump
echo
echo '#### ELIMINAZIONE VECCHI BACKUP ####'
echo
ls -dt "$SCRIPT_DIR/DBbackup/*" | tail -n $(KEEP_NUM++) | xargs rm -rf
echo
echo '#### INIZIO TRASFERIMENTO SU ALTRO SERVER ####'
echo

rsync -av -e "ssh -i $REMOTE_KEY" "$SCRIPT_DIR/DBbackup" $REMOTE_USER@$REMOTE_HOST:"$REMOTE_LOCATION"

echo
echo '#### BACKUP COMPLETATO ####'
echo
