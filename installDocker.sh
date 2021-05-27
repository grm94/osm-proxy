#!/bin/bash

sudo apt-get install -y apt-transport-https ca-certificates software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -qq update
sudo apt-get install -y docker-ce
sudo groupadd -f docker
sudo usermod -aG docker $USER
sleep 2
sudo systemctl restart docker

sudo mkdir -p /etc/systemd/system/docker.service.d
sudo bash -c 'cat <<EOF >/etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY='${HTTP_PROXY}'"
EOF'
sudo bash -c 'cat <<EOF >/etc/systemd/system/docker.service.d/https-proxy.conf
[Service]
Environment="HTTPS_PROXY='${HTTPS_PROXY}'"
EOF'

sudo systemctl daemon-reload
sudo systemctl restart docker

echo "[DONE]"
