#!/bin/bash -eEx

NWORKERS=${NWORKERS:-4}
NZONES=${NZONES:-$NWORKERS}
ZONEDIR=/var/cache/bind
KEYDIR=/var/cache/bind/keys
CIPHER=ECDSAP256SHA256
TTL=86400

fatal_error(){
    set +e
    echo
    echo "####################################################################"
    echo "## FATAL triggered by: $BASH_COMMAND"
    echo "####################################################################"
    set -x
    echo
    gdb --batch -p "$(cat /var/run/named/named.pid)" /usr/sbin/named -ex "thread apply all bt full" -ex "detach" -ex "quit"
    echo
    ps faux
    echo
    tail -10 /var/log/daemon.log
    echo
    sleep infinity
}

add_zone(){
    local domain="$1"
    rndc addzone "$domain" '{type master; file "'"$ZONEDIR/$domain.db"'"; auto-dnssec maintain; inline-signing yes; key-directory "'"$KEYDIR"'";};'
}

deladd_worker(){
    local domain="$1"
    local i=0
    trap '' ERR
    while true; do
        rndc delzone "$domain"
        add_zone "$domain"
        ((i++)) || true
        if [ $(("$i" % 100)) == 0 ];then
            printf "[%s] %d del/add\n" "$domain" "$i"
        fi
    done
}

trap fatal_error ERR

mkdir -p "$ZONEDIR" "$KEYDIR"

/etc/init.d/rsyslog start
/etc/init.d/bind9 start || /etc/init.d/named start
rndc status
set +x

echo "Generating $NZONES zones"
for n in $(seq 1 "$NZONES"); do
    domain="test${n}.local"
    tmpzone=$(mktemp)
    sed "s/{{DOMAIN}}/$domain/g" /zone.db > "$tmpzone"
    named-compilezone -o "$ZONEDIR/$domain.db" "$domain" "$tmpzone" > /dev/null
    rm "$tmpzone"
    dnssec-keygen -a "$CIPHER" -L "$TTL" -b 2048 -n ZONE -K "$KEYDIR" "$domain"  > /dev/null  2>&1
    dnssec-keygen -f KSK -a "$CIPHER" -L "$TTL" -b 4096 -n ZONE -K "$KEYDIR" "$domain"  > /dev/null 2>&1
    chown -R bind.bind "$ZONEDIR" "$KEYDIR"
    add_zone "$domain"
    printf "\r %s" "$domain"
done
echo -e "\n-> OK"

echo "Spawning $NWORKERS workers"
for n in $(seq 1 "$NWORKERS"); do
    deladd_worker "test${n}.local" &
done
echo "-> OK"

while true; do
    timeout 30s rndc status > /dev/null 2>&1
    sleep 1
done