#!/bin/bash
#------------------#

#------------------#
IPV4_PORT=3310

IPV6_ILK_PORT=10000

SOCKS5_PORT=5110
#------------------#

#------------------#
renkreset='\e[0m'
mavi='\e[1;94m'
cyan='\e[1;96m'
yesil='\e[1;92m'
kirmizi='\e[1;91m'
beyaz='\e[1;77m'
sari='\e[1;93m'
mor='\e[0;35m'
#------------------#

yukle_3proxy() {
    echo -e "\n\n\t$yesil 3Proxy Yükleniyor..\n$renkreset\n"
    # URL="https://github.com/z3APA3A/3proxy/archive/3proxy-0.8.6.tar.gz"
    URL="https://raw.githubusercontent.com/c70b65b1ddd9/centos7_proxy/main/Paketler/3proxy-3proxy-0.8.6.tar.gz"
    wget -qO- $URL | tar -xvf-       # -xf-
    cd 3proxy-3proxy-0.8.6 || exit
    make -f Makefile.Linux              # -sif
    sudo mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    sudo cp -f src/3proxy /usr/local/etc/3proxy/bin/
    sudo cp -f ./scripts/rc.d/proxy.sh /etc/init.d/3proxy
    sudo chmod +x /etc/init.d/3proxy
    sudo systemctl enable 3proxy
    cd ..
    rm -rf 3proxy-3proxy-0.8.6
    cd "$YOL" || exit
}

rastgele() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

ipv6_k=("1" "2" "3" "4" "5" "6" "7" "8" "9" "0" "a" "b" "c" "d" "e" "f")
ipv6_olustur() {
    ipv64_ver() {
        echo "${ipv6_k[$RANDOM % 16]}${ipv6_k[$RANDOM % 16]}${ipv6_k[$RANDOM % 16]}${ipv6_k[$RANDOM % 16]}"
    }
    echo "$1:$(ipv64_ver):$(ipv64_ver):$(ipv64_ver):$(ipv64_ver)"
}

veri_olustur() {
    seq $IPV6_ILK_PORT $SON_PORT | while read -r port; do
        local KULLANICI=$(rastgele)
        local SIFRE=$(rastgele)
        echo "${KULLANICI}/${SIFRE}/$IP4/$port/$(ipv6_olustur "$IP6")"
    done
}

iptable_olustur() {
    awk -F "/" '{print "sudo iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' "${VERI}"
}

ifconfig_olustur() {
    awk -F "/" '{print "sudo ifconfig eth0 inet6 add " $5 "/64"}' "${VERI}"
}

config_3proxy() {
    awk -F "/" 'BEGIN{print "daemon\nmaxconn 1000\nnscache 65536\ntimeouts 1 5 30 60 180 1800 15 60\nsetgid 65535\nsetuid 65535\nflush\nauth strong\nusers"} {print $1 ":CL:" $2 " "}' "${VERI}"
    awk -F "/" '{print "auth strong\nallow " $1 "\nproxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\nflush"}' "${VERI}"
}

squid_yukle() {
    echo -e "\n\n\t$yesil Squid Yükleniyor..\n$renkreset\n"
    sudo apt-get update
    sudo apt-get install -y squid apache2-utils
    sudo htpasswd -cb /etc/squid/passwd "$KULLANICI" "$SIFRE"

    sudo tee /etc/squid/squid.conf >/dev/null <<EOF
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
acl smtp port 25
http_access allow authenticated

http_port 0.0.0.0:${IPV4_PORT}

http_access deny smtp
http_access deny all
forwarded_for delete
EOF

    sudo cp -f /etc/squid/squid.conf /etc/init.d/squid
    sudo touch /etc/squid/blacklist.acl
    sudo systemctl restart squid.service
    sudo systemctl enable squid.service

    sudo iptables -I INPUT -p tcp --dport $IPV4_PORT -j ACCEPT

    sudo iptables-save >/dev/null
}

proxy_txt() {
    awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' "${VERI}" >proxy.txt
}

jq_yukle() {
    sudo apt-get install -y jq
}

file_io_yukle() {
    echo -e "\n\n\t$yesil Zip Yükleniyor..\n$renkreset\n"

    local PASS
    PASS=$(rastgele)
    zip --password "$PASS" proxy.zip proxy.txt >/dev/null
    JSON=$(curl -sF "file=@proxy.zip" https://file.io)
    URL=$(echo "$JSON" | jq --raw-output '.link')

    clear
    echo -e "\n\n\t$yesil Proxyler Hazır!$mor Format »$sari IP:PORT:KULLANICI:SIFRE$renkreset"
    echo -e "\n$mor IPv6 Zip İndirme Bağlantısı:$yesil ${URL}$renkreset"
    echo -e "$mor IPv6 Zip Şifresi:$yesil ${PASS}$renkreset"
}

socks5_yukle() {
    echo -e "\n\n\t$yesil Dante SOCKS5 Yükleniyor..\n$renkreset\n"

    wget -qO dante_socks.sh https://raw.githubusercontent.com/Lozy/danted/master/install_centos.sh
    chmod +x dante_socks.sh
    sudo ./dante_socks.sh --port="$SOCKS5_PORT" --user="$KULLANICI" --passwd="$SIFRE"
    rm -rf dante_socks.sh

    sudo iptables -I INPUT -p tcp --dport "$SOCKS5_PORT" -j ACCEPT
    sudo iptables-save >/dev/null
}

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo -e "\n\t$sari IPv4 »$yesil ${IP4}$sari | IPv6 için Sub »$yesil ${IP6}$renkreset"
echo -e "\n\n\t$yesil Gerekli Paketler Yükleniyor..$renkreset\n"
sudo apt-get update
sudo apt-get install -y gcc net-tools bsdtar zip

if [[ -z $IP6 ]]; then
    squid_yukle
    socks5_yukle
    clear
    echo -e "\n\n\t$kirmizi Makinenizin IPv6 Desteği Bulunmamaktadır..$renkreset\n"
    echo -e "\n$sari IPv4   Proxy »$yesil ${IP4}:${IPV4_PORT}:${KULLANICI}:${SIFRE}$renkreset"
    echo -e "$sari SOCKS5 Proxy »$yesil ${IP4}:${SOCKS5_PORT}:${KULLANICI}:${SIFRE}$renkreset\n"
    exit 0
fi

yukle_3proxy

echo -e "\n\n$sari Çalışma Dizini » /home/CentOS_Proxi_Yukle$renkreset"
YOL="/home/CentOS_Proxi_Yukle"
VERI="${YOL}/veri.txt"
mkdir -p "$YOL" && cd "$_" || exit

echo -e "\n$mor Kaç adet IPv6 proxy oluşturmak istiyorsunuz?$kirmizi Örnek 500 : $renkreset"
read -r ADET
echo -e "\n\n"

SON_PORT=$((IPV6_ILK_PORT + ADET))

veri_olustur >veri.txt
iptable_olustur >iptable_yapilandir.sh
ifconfig_olustur >ifconfig_yapilandir.sh

config_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
bash ${YOL}/iptable_yapilandir.sh >/dev/null
bash ${YOL}/ifconfig_yapilandir.sh >/dev/null
ulimit -n 10048
service 3proxy start
EOF

sudo bash /etc/rc.local

squid_yukle && socks5_yukle && proxy_txt && jq_yukle && file_io_yukle

echo -e "\n$sari IPv4   Proxy »$yesil ${IP4}:${IPV4_PORT}:${KULLANICI}:${SIFRE}$renkreset"
echo -e "$sari SOCKS5 Proxy »$yesil ${IP4}:${SOCKS5_PORT}:${KULLANICI}:${SIFRE}$renkreset\n"
