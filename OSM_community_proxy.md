# OSM Installation behind a proxy server for internet access

## Initial proxy setup

Make user `vagrant` able to use `sudo` without password:

```text
vagrant ALL=(ALL) NOPASSWD: ALL
```

Setup proxy configuration in the VM:

```bash
${HOME}/osm_install/setProxyEnvVariables.sh
exit
```

Download devops public repo:

```bash
cd ${HOME}
git clone "https://osm.etsi.org/gerrit/osm/devops"
```

## Docker Install

Prepare docker to use proxy configuration:

```bash
${HOME}/osm_install/installDocker.sh
```

## Kubernetes Install

Install Kubernetes using kubeadm. Required to create VCA in the next step:

```bash
${HOME}/osm_install/installKube.sh
${HOME}/osm_install/initKube.sh
```

Update `/etc/environment` with kubernetes cluster IP address `kubectl get svc` and `exit`.
Required for OSM Operators (mongodb).

## Juju (VCA) in K8s

Bootstrap a Juju controller (VCA) in Kubernetes. Proxy configuration needed

```bash
${HOME}/osm_install/setupJuju.sh
${HOME}/osm_install/bootstrapJuju.sh
```

As an output, a file named `${HOME}/jujucontroller.rc` will be created. Needed at OSM installation time.

## OSM install

Download community installer, load VCA credentials and install:

```bash
cd $HOME

wget https://osm-download.etsi.org/ftp/osm-9.0-nine/install_osm.sh

chmod +x install_osm.sh
# Load Juju controller credentials as env variables
source ${HOME}/jujucontroller.rc

# Workaround. Added -E option to sudo command in order to be able to get pip packages via proxy.
sudo -E -H LC_ALL=C python3 -m pip install -U pip
sudo -E -H LC_ALL=C python3 -m pip install -U python-magic pyangbind verboselogs

# CONTROLLER_IP_ADDR contains VCA ip address. CONTROLLER_PASSWD contains created password. Pointing to tag 9.1.0
./install_osm.sh -y -H $CONTROLLER_IP_ADDR -S $CONTROLLER_PASSWD -P $HOME/.local/share/juju/ssh/juju_id_rsa.pub --nodocker -t 9.1.1
```

## Post-install

Modify LCM definition with `sudo vi /etc/osm/docker/osm_pods/lcm.yaml`:

```yaml
        - name: HTTP_PROXY
          value: http://172.17.86.108:8080
        - name: HTTPS_PROXY
          value: http://172.17.86.108:8080
        - name: no_proxy
          value: localhost,127.0.0.1,ro,nbi,kafka,keystone,10.232.120.3,10.232.99.197,10.232.99.198,172.17.62.25,158.230.4.112,158.230.106.56,10.244.0.1
```

Apply changes:

```bash
kubectl apply -n osm -f /etc/osm/docker/osm_pods/lcm.yaml
```
