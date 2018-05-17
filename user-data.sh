#! /bin/bash

source config

mkdir config-drives
mkdir config-drives/vm1-config
mkdir config-drives/vm2-config

userdata="#!/bin/bash\n
mount /dev/cdrom /mnt/\n
cp -r /mnt/repo /root/repo\n
mkdir -p /root/.ssh\n
cat /home/ubuntu/.ssh/authorized_keys > /root/.ssh/authorized_keys\n
chmod 600 /root/.ssh/authorized_keys\n"

natuserdata="sysctl net.ipv4.ip_forward=1\n
iptables -t nat -A POSTROUTING -o $VM1_EXTERNAL_IF -j MASQUERADE\n
ip link add ${VXLAN_IF} type vxlan id ${VID} dev ${VM1_INTERNAL_IF} dstport 0\n
bridge fdb append to 00:00:00:00:00:00 dst ${VM2_INTERNAL_IP} dev ${VXLAN_IF}\n
ip addr add ${VM1_VXLAN_IP}/30 dev ${VXLAN_IF}\n
ip link set up dev ${VXLAN_IF}\n
apt-get update\n
apt-get install apt-transport-https ca-certificates curl software-properties-common -qq -y\n
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -\n
apt-key fingerprint 0EBFCD88\n
add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\"\n
apt-get update\n
apt-get install docker-ce -qq -y\n
mkdir /srv/docker\n
mkdir /srv/docker/certs\n
mkdir /srv/docker/log\n
mkdir /srv/docker/etc\n
mkdir /srv/docker/etc/certs"

dockerce="ip link add ${VXLAN_IF} type vxlan id ${VID} dev ${VM2_INTERNAL_IF} dstport 0\n
bridge fdb append to 00:00:00:00:00:00 dst ${VM1_INTERNAL_IP} dev ${VXLAN_IF}\n
ip addr add ${VM2_VXLAN_IP}/30 dev ${VXLAN_IF}\n
ip link set up dev ${VXLAN_IF}\n
while ! ping -q -w 1 -c 1 8.8.8.8 > /dev/null; do\n
sleep 5\n
done\n
apt-get update\n
apt-get install apt-transport-https ca-certificates curl software-properties-common -qq -y\n
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -\n
apt-key fingerprint 0EBFCD88\n
add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\"\n
apt-get update\n
apt-get install docker-ce -qq -y\n"


docerNginxCerts="apt-get install openssl -y -qq\n
\n
openssl genrsa -out /srv/docker/certs/root.key 4096\n
openssl req -new -key /srv/docker/certs/root.key -days 365 -nodes -x509 -subj \"/C=UA/ST=Kharvovskaya obl./L=Kharkov/O=Mirantis Matveev/CN=RootCA\" -out /srv/docker/certs/root.crt\n
\n
curdir=\$(pwd)\n
openssl genrsa -out /srv/docker/certs/web.key 4096\n
\n
openssl req -new -key /srv/docker/certs/web.key -subj \"/C=UA/ST=Kharvovskaya obl./L=Kharkov/O=Mirantis Matveev/CN=$VM1_NAME\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]subjectAltName=IP:$VM1_EXTERNAL_IP\")) -out /srv/docker/certs/web.crt\n
\n
\n
openssl x509 -req -extfile <(printf \"subjectAltName=IP:$VM1_EXTERNAL_IP\") -days 365 -CA /srv/docker/certs/root.crt -CAkey /srv/docker/certs/root.key -CAcreateserial -in /srv/docker/certs/web.crt -out /srv/docker/certs/web.crt \n
\n
cat /srv/docker/certs/root.crt >> /srv/docker/certs/web.crt" 

nginxconfig="echo -e \"user www-data;\\n
worker_processes auto;\\n
pid /var/run/nginx.pid;\\n                   
worker_rlimit_nofile 65536;\\n               
\\n
events {\\n                                  
        use epoll;\\n                        
        worker_connections 32768;\\n         
        multi_accept on;\\n                  
}\\n                                         
http {\\n                                    
        sendfile on;\\n                      
        tcp_nopush on;\\n                    
        tcp_nodelay on;\\n                   
        keepalive_timeout 30;\\n             
        keepalive_requests 100;\\n                                                      
        types_hash_max_size 2048;\\n         
        client_body_timeout 10;\\n           
        send_timeout 2;\\n                   
        reset_timedout_connection on;\\n     
        proxy_next_upstream http_500 http_502 http_503 http_504;\\n                     
\\n
        server_tokens off;\\n                
\\n
\\n
        ##\\n                                
        # Gzip Settings                   \\n
        ##                                \\n
\\n
        gzip on;                          \\n
        gzip_disable \"msie6\";             \\n
        gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;                            \\n
\\n
\\n
server {                                  \\n
        listen 443 ssl;                  \\n
        ssl_certificate     /etc/nginx/certs/web.crt;  \\n
        ssl_certificate_key /etc/nginx/certs/web.key;\\n
        ssl_session_timeout 1d;          \\n
        ssl_session_cache shared:SSL:50m;\\n
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;                                        
        ssl_prefer_server_ciphers on;\\n
        ssl_ciphers 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:EC\\n
DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SH\\n
A384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES\\n
256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC\\n
3-SHA:!DSS';                              \\n
\\n
        server_name nginx;                \\n
\\n
\\n
    location /                            \\n
        {                                 \\n
            proxy_pass http://$VM2_VXLAN_IP:$APACHE_PORT;   \\n
        }                                 \\n
        }                                 \\n
\\n
}\" > /srv/docker/etc/nginx.conf"

ngnixdocker="docker run -dit -p $NGINX_PORT:443 -v /srv/docker/etc:/etc/nginx -v /srv/docker/certs/:/etc/nginx/certs -v $NGINX_LOG_DIR:/var/log/nginx/ nginx:1.13"

apachedocker="docker run -dit -p $APACHE_PORT:80 httpd:2.4"

echo -e $userdata > config-drives/vm1-config/user-data
echo -e $natuserdata >> config-drives/vm1-config/user-data
echo -e $docerNginxCerts >> config-drives/vm1-config/user-data
echo -e $nginxconfig >> config-drives/vm1-config/user-data
echo -e $ngnixdocker >> config-drives/vm1-config/user-data

echo -e $userdata > config-drives/vm2-config/user-data
echo -e $dockerce >> config-drives/vm2-config/user-data
echo -e $apachedocker >> config-drives/vm2-config/user-data
