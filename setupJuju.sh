#!/bin/bash

# Apply sysctl production values for optimal performance
sudo bash -c 'cat <<EOF >/etc/sysctl.d/60-lxd-production.conf
fs.inotify.max_queued_events=1048576
fs.inotify.max_user_instances=1048576
fs.inotify.max_user_watches=1048576
vm.max_map_count=262144
kernel.dmesg_restrict=1
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv6.neigh.default.gc_thresh3=8192
net.core.bpf_jit_limit=3000000000
kernel.keys.maxkeys=2000
kernel.keys.maxbytes=2000000
EOF'

sudo sysctl --system

# Install LXD
sudo apt-get remove --purge -y liblxc1 lxc-common lxcfs lxd lxd-client
sudo snap install lxd

# Configure LXD
sudo usermod -a -G lxd `whoami`
DEFAULT_IF=$(ip route list|awk '$1=="default" {print $5; exit}')
DEFAULT_IP=`ip -o -4 a s ${DEFAULT_IF} |awk '{split($4,a,"/"); print a[1]}'`
DEFAULT_MTU=$(ip addr show ${DEFAULT_IF} | perl -ne 'if (/mtu\s(\d+)/) {print $1;}')

cat <<EOF >${HOME}/lxd-preseed.conf
config: {}
networks:
- config:
    ipv4.address: auto
    ipv6.address: none
  description: ""
  managed: false
  name: lxdbr0
  type: ""
storage_pools:
- config:
    size: 100GB
  description: ""
  name: default
  driver: btrfs
profiles:
- config: {}
  description: ""
  devices:
    eth0:
      name: eth0
      nictype: bridged
      parent: lxdbr0
      type: nic
    root:
      path: /
      pool: default
      type: disk
  name: default
cluster: null
EOF

cat ${HOME}/lxd-preseed.conf | sed 's/^config: {}/config:\n  core.https_address: '$DEFAULT_IP':8443/' | sg lxd -c "lxd init --preseed"
sg lxd -c "lxd waitready"
sg lxd -c "lxc profile device set default eth0 mtu $DEFAULT_MTU"
sg lxd -c "lxc network set lxdbr0 bridge.mtu $DEFAULT_MTU"

## LXD Configuration
lxc config set core.proxy_http ${HTTP_PROXY}
lxc config set core.proxy_https ${HTTPS_PROXY}
lxc config set core.proxy_ignore_hosts ${no_proxy}

## Juju proxy configuration
cat <<EOF >~/bootstrap-config.yaml
default-series: bionic
apt-http-proxy: ${HTTP_PROXY}
apt-https-proxy: ${HTTPS_PROXY}
juju-http-proxy: ${HTTP_PROXY}
juju-https-proxy: ${HTTPS_PROXY}
juju-no-proxy: ${no_proxy}
snap-http-proxy: ${HTTP_PROXY}
snap-https-proxy: ${HTTPS_PROXY}
EOF

## install Juju
sudo snap install juju --classic --channel=2.8/stable
sudo usermod -a -G lxd $USER
