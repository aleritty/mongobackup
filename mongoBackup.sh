#!/bin/bash

############################################################################################################
#
# Mongo Backup Script
# Autor: Aleritty <aleritty//#AT#//aleritty.net> http://www.aleritty.net
#	Questo script permette di effettuare backup di un database
#
#	Esecuzione:
#		~$ sudo /bin/bash mongoBackup.sh [ -h --help]
#
# Copyright (c) 2016 Aleritty
#
#	Questo script è rilasciato sotto licenza creative commons:
#		http://creativecommons.org/licenses/by-nc-sa/2.5/it/
#	E' quindi possibile: riprodurre, distribuire, comunicare al pubblico,
#	esporre in pubblico, eseguire, modificare quest'opera
#	Alle seguenti condizioni:
#	Attribuzione. Devi attribuire la paternità dell'opera nei modi indicati
#	dall'autore o da chi ti ha dato l'opera in licenza e in modo tale da non
#	suggerire che essi avallino te o il modo in cui tu usi l'opera.
#
#	Non commerciale. Non puoi usare quest'opera per fini commerciali.
#
#	Condividi allo stesso modo. Se alteri o trasformi quest'opera, o se la usi
#	per crearne un'altra, puoi distribuire l'opera risultante solo con una
#	licenza identica o equivalente a questa.
#
#	Questo script agisce su indicazioni e conferma dell'utente, pertanto
#	l'autore non si ritiene responsabile di qualsiasi danno o perdita di dati
#	derivata dall'uso improprio o inconsapevole di questo script!

VERSION=0.06

######################### Se non sei root non sei figo #########################
if [[ $EUID -ne 0 ]]; then
	echo
	echo "ERRORE: Devi avere i privilegi da superutente per lanciarmi"
	echo
	exit 1
fi

TIMESTAMP=$(date +"%F_%H-%M")
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"
if [ -e ".mongoBackup.cfg" ]; then
  source .mongoBackup.cfg
else
  echo
  echo "Non hai ancora compilato le configurazioni, fallo e poi rilanciami"
  echo
  exit 1
fi

###Controlla esistenza di mongodump senno chiedi ed installa
MONGODUMP_PATH=`command -v mongodump 2>&1 || { echo >&2 "Mi serve mongodump, senza non posso fare nulla, installalo"; exit 1; }`

if [ ! -d "$BACKUP_LOCATION" ]; then
  mkdir -p "$BACKUP_LOCATION"
fi
cd "$BACKUP_LOCATION"

##################### Aggiornamento dello script da github #####################
upgradescript(){
  echo
  echo "Cerco aggiornamenti..."
  echo
	gitversion=$(wget https://github.com/aleritty/mongobackup/raw/master/mongoBackup.sh -O - 2>/dev/null | grep "^VERSION=")
	if [[ ${gitversion:8} > $VERSION ]];then
		echo
    echo "Trovato aggiornamento..."
    echo
    cd "$SCRIPT_DIR"
    # scelta se aggiornare...
    git pull
		clear
    echo "Aggiornamento terminato, rilancia lo script per effettuare il backup"
		exit 0
	else
    echo
    echo "Nessun aggiornamento necessario, hai l'ultima versione dello script"
    echo
  fi
}

################ INSTALLAZIONE CRONJOB #########################################
crontab -l > /tmp/mycron-mongoBackup
sed -i '/mongoBackup.sh/d' /tmp/mycron-mongoBackup
cronLen=${#CRON_WHEN[@]}
for (( i=0; i<${cronLen}; i++ )); do
	echo "${CRON_WHEN[$i]} /bin/bash "$SCRIPT_DIR"/mongoBackup.sh" >> /tmp/mycron-mongoBackup
done
crontab /tmp/mycron-mongoBackup
rm /tmp/mycron-mongoBackup

################# Sezione help ed invocazioni particolari ######################
if [[ "$1" = "--help" || "$1" = "-h" ]]; then
	echo
	echo "Mongo-Backup $VERSION
Written By AleRitty <aleritty@aleritty.net>
Effettua Backup di Database Mongo

Usage:
sudo /bin/bash mongoBackup.sh [ --upd ]

--upd 	Aggiorna lo script all'ultima versione
--help	Mostra questa schermata

L'invocazione normale senza parametri lancia il backup secondo le configurazioni
impostate nel file .config

"
	exit 1
fi

if [[ "$1" = "--upd" || "$1" = "-u" ]]; then
	echo
	echo "Vuoi che aggiorni? Ok, aggiorno..."
	upgradescript
	exit 0
fi

echo
echo '#### INIZIO BACKUP ####'
echo

DBSTRING=''
if [ ! -z "$MONGO_ONLY_DB" ];then for DB in $MONGO_ONLY_DB; do DBSTRING+="--db $DB "; done; fi

COLSTRING=''
if [ ! -z "$MONGO_ONLY_COLLECTION" ];then for DB in $MONGO_ONLY_COLLECTION;	do COLSTRING+="-c $DB "; done; fi

if [[ "$MONGO_USE_AUTH" = "true" ]]; then
	$MONGODUMP_PATH --host $MONGO_HOST -u $MONGO_USER -p $MONGO_PW $DBSTRING $COLSTRING
else
	$MONGODUMP_PATH --host $MONGO_HOST $DBSTRING $COLSTRING
fi

echo
echo '#### COMPRESSIONE DATI ####'
echo '#### può richiedere un po di tempo ####'
echo
tar -jcf "$BACKUP_PREFIX-$TIMESTAMP.tar.bz2" dump; rm -rf dump

echo
echo '#### ELIMINAZIONE VECCHI BACKUP ####'
echo
if [ "$KEEP_NUM" -gt -1 ]; then
  echo
  echo "questi backup verranno eliminati"
  #conferma?
  ls -dt "$BACKUP_LOCATION"* | tail -n +$((KEEP_NUM+1))
  ls -dt "$BACKUP_LOCATION"* | tail -n +$((KEEP_NUM+1)) | xargs rm -rf
fi

bkLen=${#REMOTE_HOST[@]}
for (( i=0; i<${bkLen}; i++ ));
do
	echo
	echo '#### INIZIO TRASFERIMENTO SUL SERVER '${REMOTE_HOST[$i]}' ####'
	echo
	rsync -av -e "ssh -i ${REMOTE_KEY[$i]}" "${BACKUP_LOCATION[$i]}" ${REMOTE_USER[$i]}@${REMOTE_HOST[$i]}:"${REMOTE_LOCATION[$i]}" --delete
done

echo
echo
echo '###########################'
echo '#### BACKUP COMPLETATO ####'
echo '###########################'
echo
echo
