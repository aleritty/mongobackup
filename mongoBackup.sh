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

VERSION=0.04

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
if [ -e ".config" ]; then
  source .config
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

###INSTALLAZIONE CRONJOB (CON ESECUZIONE VIA BASH)
### Check cronjob per backup
### Eliminazione cronjob per backup
### idem per update?
########################### Gestione anacron ###################################
yo_cron(){
	if [ ! -f "/etc/cron.daily/99Zkernelupdate" ];then
		dialog --clear --backtitle "$maintitle" --title "Installazione in anacron" --yesno "Vuoi installare il controllo settimanale degli aggiornamenti del kernel? Verrà utilizzato anacron per il controllo. Verrai notificato ogni settimana se sono stati trovati aggiornamenti. E' necessario installare lo script a livello di sistema." 10 60
		yesno=$?
		if [ "$yesno" = "0" ];then
			touch "/etc/cron.daily/99Zkernelupdate"
			chmod +x "/etc/cron.daily/99Zkernelupdate"
			echo '#!/bin/bash' > "/etc/cron.daily/99Zkernelupdate"
			echo '/usr/sbin/kernel-update --chk' >> "/etc/cron.weekly/99Zkernelupdate"
			if [ ! -e "/usr/sbin/kernel-update" ];then
				yo_manage
			fi
			dialog --title "Installato" --msgbox "Controllo settimanale installato correttamente" 5 60
		fi
	else
		dialog --clear --backtitle "$maintitle" --title "Disinstallazione da anacron" --yesno "Vuoi disinstallare il controllo settimanale degli aggiornamenti del kernel?" 10 60
		yesno=$?
		if [ "$yesno" = "0" ];then
			rm /etc/cron.weekly/99Zkernelupdate
			dialog --title "Disinstallato" --msgbox "Controllo disinstallato correttamente" 5 60
		fi
	fi
  #######metodo alternativo con cron
  # #write out current crontab
  # crontab -l > mycron
  # #echo new cron into cron file
  # echo "* * * 4 4 /bin/bash "$SCRIPT_DIR"/mongoBackup.sh >> mycron
  # #install new cron file
  # crontab mycron
  # rm mycron
  # permette di scegliere meglio le ore quando farlo

}

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
if [ "$KEEP_NUM" -gt -1 ]; then
  echo
  echo "questi backup verranno eliminati"
  #conferma?
  ls -dt "$BACKUP_LOCATION"* | tail -n +$((KEEP_NUM+1))
  ls -dt "$BACKUP_LOCATION"* | tail -n +$((KEEP_NUM+1)) | xargs rm -rf
fi

echo
echo '#### INIZIO TRASFERIMENTO SU ALTRO SERVER ####'
echo
rsync -av -e "ssh -i $REMOTE_KEY" "$BACKUP_LOCATION" $REMOTE_USER@$REMOTE_HOST:"$REMOTE_LOCATION" --delete

echo
echo '#### BACKUP COMPLETATO ####'
echo
