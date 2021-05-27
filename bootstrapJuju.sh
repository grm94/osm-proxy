#!/bin/bash

OSM_VCA_K8S_CLOUDNAME="k8scloud"
OSM_STACK_NAME=osm
JUJU_AGENT_VERSION=2.8.6

cat $HOME/.kube/config | juju add-k8s $OSM_VCA_K8S_CLOUDNAME --client
juju bootstrap $OSM_VCA_K8S_CLOUDNAME $OSM_STACK_NAME  \
   --config controller-service-type=loadbalancer \
   --agent-version=$JUJU_AGENT_VERSION --no-gui --debug \
   --model-default $HOME/bootstrap-config.yaml

controller_ip=$(juju show-controller osm|grep api-endpoints|awk -F\' '{print $2}'|awk -F\: '{print $1}')
function parse_juju_password {    password_file="${HOME}/.local/share/juju/accounts.yaml";    local controller_name=$1;    local s='[[:space:]]*' w='[a-zA-Z0-9_-]*' fs=$(echo @|tr @ '\034');    sed -ne "s|^\($s\):|\1|"         -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p"         -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $password_file |    awk -F$fs -v controller=$controller_name '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         if (match(vn,controller) && match($2,"password")) {
             printf("%s",$3);
         }
      }
   }'; }
juju_password=$(parse_juju_password osm)

cat <<EOF >~/jujucontroller.rc
export CONTROLLER_IP_ADDR=${controller_ip}
export CONTROLLER_PASSWD=${juju_password}
EOF
