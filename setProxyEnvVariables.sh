#!/bin/bash

# HTTP_PROXY=http://10.95.85.201:8000
# HTTPS_PROXY=http://10.95.85.201:8000
# IGNORE_HOSTS=localhost,10.95.85.107,10.95.85.219

HTTP_PROXY=http://172.17.86.108:8080
HTTPS_PROXY=http://172.17.86.108:8080
IGNORE_HOSTS=localhost,127.0.0.1,ro,nbi,kafka,keystone,10.232.120.3,10.232.99.197,10.232.99.198,172.17.62.25,158.230.4.112,158.230.106.56,,10.244.0.1

sudo bash -c 'cat <<EOF >>/etc/environment
http_proxy="'${HTTPS_PROXY}'"
https_proxy="'${HTTPS_PROXY}'"
additional_no_proxy="'${IGNORE_HOSTS}'"
no_proxy="'${IGNORE_HOSTS}'"
HTTP_PROXY="'${HTTPS_PROXY}'"
HTTPS_PROXY="'${HTTPS_PROXY}'"
EOF'

echo "[DONE]"
