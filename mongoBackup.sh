#!/bin/bash

echo
echo '#### INIZIO BACKUP ####'
echo

MONGODUMP_PATH="/usr/bin/mongodump"
MONGO_HOST="localhost"
TIMESTAMP=$(date +"%F_%H-%M")

# Create backup
cd /root/DBbackup/
$MONGODUMP_PATH --host $MONGO_HOST

# Add timestamp to backup
echo
echo '#### COMPRESSIONE DATI ####'
echo '#### può richiedere un po di tempo ####'
echo
tar -jcf mongodb-CDAT-$TIMESTAMP.tar.bz2 dump;rm -rf dump

echo
echo '#### ELIMINAZIONE VECCHI BACKUP ####'
echo
ls -dt /root/DBbackup/* | tail -n +11 | xargs rm -rf
echo
echo '#### INIZIO TRASFERIMENTO SU ALTRO SERVER ####'
echo

rsync -av -e "ssh -i /home/aleritty/.ssh/id_rsa" /root/DBbackup aleritty@10.220.98.35:/home/aleritty/DBCDAT

echo
echo '#### BACKUP COMPLETATO ####'
echo
