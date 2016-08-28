#!/bin/bash

###INSTALLAZIONE CRONJOB (CON ESECUZIONE VIA BASH)
### Check cronjob
### Eliminazione cronjob

###controllo aggiornamenti


echo
echo '#### INIZIO BACKUP ####'
echo

TIMESTAMP=$(date +"%F_%H-%M")

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
source .config

###Controlla esistenza di mongodump senno chiedi ed installa
MONGODUMP_PATH=`command -v mongodump 2>&1 || { echo >&2 "Mi serve mongodump, senza non posso fare nulla, installalo"; exit 1; }`

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
ls -dt "$SCRIPT_DIR/DBbackup/"* | tail -n $(KEEP_NUM++) | xargs rm -rf
echo
echo '#### INIZIO TRASFERIMENTO SU ALTRO SERVER ####'
echo

rsync -av -e "ssh -i $REMOTE_KEY" "$SCRIPT_DIR/DBbackup" $REMOTE_USER@$REMOTE_HOST:"$REMOTE_LOCATION"

echo
echo '#### BACKUP COMPLETATO ####'
echo
