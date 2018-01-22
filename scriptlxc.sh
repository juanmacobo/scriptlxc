#!/bin/bash

bucle1="continuar"

echo "Esperando un stress al contenedor1..."

while [ $bucle1 != "parar" ]; do

	#Ver ip contenedor1
	ipcont1=$(lxc-info -n contenedor1 | grep 'IP' | tr -s " " | cut -d " " -f 2)

	#Saber RAM libre:
	LIB=$(lxc-info -n contenedor1 | grep 'Memory use' | tr -s " " | cut -d " " -f 3 | cut -d "." -f 1)
	MAX=400	
	if [ $LIB -gt $MAX ]
	then
		echo "Contenedor1 sin memoria"
		echo " "
		echo "Desmontando disco adicional del contenedor1"
     		lxc-attach -n contenedor1 -- umount /dev/mapper/vgsistema-discoadlxc 
		lxc-device -n contenedor1 del /dev/mapper/vgsistema-discoadlxc 
		
		echo " "
		echo "Borrando regla iptable contenedor1"
		deliptable=$(iptables -t nat -L --line-number | grep $ip1 | cut -d " " -f 1)	
		iptables -t nat -D PREROUTING $deliptable

		sleep 2

		ipcont2=$(lxc-info -n contenedor2 | grep 'IP' | tr -s " " | cut -d " " -f 2)
		echo " "
		echo "Añadiendo regla iptable contenedor2"
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $ipcont2:80
		
		echo " "
		echo "Montando disco adicional contenedor2"
		lxc-device -n contenedor2 add /dev/mapper/vgsistema-discoadlxc 
		lxc-attach -n contenedor2 -- mount /dev/mapper/vgsistema-discoadlxc /var/www/html
		lxc-attach -n contenedor2 -- systemctl restart apache2

		echo " "
		echo "Contenedor2 disponible"

		bucle1="parar"
	fi
done

echo " "
echo "Esperando un stress al contenedor2"

bucle2="continuar"
while [ $bucle2 != "parar" ]; do
	LIB2=$(lxc-info -n contenedor2 | grep 'Memory use' | tr -s " " | cut -d " " -f 3 | cut -d "." -f 1)
	MAX2=800	
	if [ $LIB2 -gt $MAX2 ]
	then
		echo " "
		echo "Contenedor2 sin memoria"
		echo " "
		echo "Aumentando memoria RAM del contenedor2 a 2 GiB..."
		lxc-cgroup -n contenedor2 memory.limit_in_bytes 2G
		echo "Memoria RAM aumentada"
		bucle2="parar"
	fi
done
