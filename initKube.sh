#!/bin/bash

OSM_DEVOPS=${HOME}/devops
DEFAULT_IF=$(ip route list|awk '$1=="default" {print $5; exit}')
DEFAULT_IP=`ip -o -4 a s ${DEFAULT_IF} |awk '{split($4,a,"/"); print a[1]}'`

cat <<EOF >${HOME}/cluster-config.yaml
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
networking:
  podSubnet: 10.244.0.0/16
apiServer:
  extraArgs:
    service-node-port-range: "80-32767"
EOF

# Init cluster
sudo swapoff -a
sudo kubeadm init --config ${HOME}/cluster-config.yaml
sleep 5

# Prepare kube config
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Delete old NS
kubectl delete ns osm

# Create CNI
CNI_DIR="$(mktemp -d -q --tmpdir "flannel.XXXXXX")"
trap 'rm -rf "${CNI_DIR}"' EXIT
wget -q https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml -P $CNI_DIR
kubectl apply -f $CNI_DIR
[ $? -ne 0 ] && FATAL "Cannot Install Flannel"

# Taint master node
K8S_MASTER=$(kubectl get nodes | awk '$3~/master/'| awk '{print $1}')
kubectl taint node $K8S_MASTER node-role.kubernetes.io/master:NoSchedule-
sleep 5

# Install OpenEBS
kubectl apply -f https://openebs.github.io/charts/openebs-operator-1.6.0.yaml
storageclass_timeout=300
counter=0
echo "Waiting for storageclass"
while (( counter < storageclass_timeout ))
do
    kubectl get storageclass openebs-hostpath &> /dev/null

    if [ $? -eq 0 ] ; then
        echo "Storageclass available"
        break
    else
        counter=$((counter + 15))
        sleep 15
    fi
done
kubectl patch storageclass openebs-hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Install and set metallb
METALLB_IP_RANGE=$DEFAULT_IP-$DEFAULT_IP

cat ${OSM_DEVOPS}/installers/k8s/metallb/metallb.yaml | kubectl apply -f -

echo "apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $METALLB_IP_RANGE" | kubectl apply -f -

echo "[DONE]"
