#!/usr/bin/env bash

while [ $# -gt 0 ]; do
        key="$1"
        
        case "${key}" in
        -d | --domain)
        	target_domain="$2"
        	shift
        	shift
        	;;
    	-i | --ip)
    		target_ip="$2"
    		shift
    		shift
    		;;
		*)
			POSITIONAL="${POSITIONAL} $1"
			shift
			;;
		esac
done

echo
echo
echo "--- Creating folder structure ---"
mkdir 
mkdir -p $target_domain/{Admin,Deliverables,Evidence/{Findings,Scans/{DNS,NMAP,Vuln,Service,Web,'AD Enumeration'},Notes,OSINT,Wireless,'Logging output','Misc Files'},Retest}

if [[ $? != 0 ]]; then
	echo "[-] Folder creation failed!"
	exit
else
	echo "[+] Folders created"
	tree $target_domain
fi

echo
echo
echo "--- Running basic NMAP scan---"
nmap $target_ip -oN $target_domain/Evidence/Scans/NMAP/1_basic_$target_ip

echo
echo
echo "--- Running aggressive NMAP scan ---"
nmap $target_ip -oN $target_domain/Evidence/Scans/NMAP/2_aggressive_$target_ip -A

echo
echo
echo "--- Checking if DNS is running on host ---"
cat $target_domain/Evidence/Scans/NMAP/1_basic_$target_ip | grep domain | grep open
if [[ $? != 0 ]]; then
	echo "[-] DNS dosn't appear to be running on host"
else
	echo "[+] DNS appears to be running on host"
	echo "--- Attempting DNS transfer ---"
	dig axfr $target_domain @$target_ip | tee $target_domain/Evidence/Scans/DNS/dns_$target_domain.txt
fi

echo
echo
echo "--- Checking for HTTP(s) services ---"
cat $target_domain/Evidence/Scans/NMAP/1_basic_$target_ip | grep http$ | grep open
echo
if [[ $? != 0 ]]; then
    echo "[-] HTTP services don't appear to be available"
else
    echo "[+] HTTP services appear to be running"
    echo
    echo "--- Getting default content-length from $target_domain"
    default_fs=$(curl -s -I http://${target_domain} | gawk -v IGNORECASE=1 '/^Content-Length/ { print $2 }')
    echo "The default_fs should be: $default_fs"
    read -p "Confirm the default_fs: > " fs_entered
fi

echo
echo
echo "--- Looking for virtual hosts ---"
ffuf -w /opt/useful/SecLists/Discovery/DNS/namelist.txt:FUZZ -u http://${target_domain} -H "Host: FUZZ.${target_domain}" -fs $fs_entered | tee $target_domain/Evidence/Scans/DNS/ffuf_$target_domain.txt
cat $target_domain/Evidence/Scans/DNS/ffuf_$target_domain.txt | grep -i ^[a-z] | cut -d" " -f1 > $target_domain/Evidence/Scans/DNS/subdomains_$target_domain.txt
