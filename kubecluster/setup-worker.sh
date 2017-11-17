#!/bin/bash
function usage() {
  echo "Usage:"
  echo "Note: Update the cluster settings in k8sinit before running $0"
  echo "Note: Make sure SSL keys for worker node is generated on master node and copied to /etc/kubernetes/ssl on worker node along with ca.pem before running $0"
  echo "$0 <WORKER_NODE_FQDN>"
  exit 0
}

if [ $# -lt 1 ]; then
  usage
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  usage
fi

SSL_CERT_DIR="/etc/kubernetes/ssl"
if [ ! -d ${SSL_CERT_DIR} ]; then 
  mkdir -p ${SSL_CERT_DIR}
  chmod 600 ${SSL_CERT_DIR}
  chown root:root ${SSL_CERT_DIR}
fi

if [ "${1}" != "" ]; then
  if [ ! -f ${SSL_CERT_DIR}/${1}-worker.pem ] || [ ! -f ${SSL_CERT_DIR}/${1}-worker-key.pem ]; then
    echo "Make sure SSL keys for worker node ${1} is generated on master node and copied to /etc/kubernetes/ssl on worker node ${1} along with ca.pem before running $0"
    exit 1
  fi
fi

pushd ${SSL_CERT_DIR}
if [ ! -f ${1}-worker.pem ]; then
  echo "Can't find ${1}-worker.pem in ${SSL_CERT_DIR}. Will exit now"
  exit 1
else
  ln -sf ${1}-worker.pem worker.pem
fi
if [ ! -f ${1}-worker-key.pem ]; then
  echo "Can't find ${1}-worker-key.pem in ${SSL_CERT_DIR}. Will exit now"
  exit 1
else
  ln -sf ${1}-worker-key.pem worker-key.pem
fi
if [ ! -f ca.pem ]; then
  echo "Can't find ca.pem in ${SSL_CERT_DIR}. kubectl would not work as expected"
fi
chmod 600 *.pem
chown root:root *.pem
popd

echo -en "Did you define and configure the cluster settings in ./k8sinit? (yes/no) \n"
while :
do
  read input
  case $input in
    yes|Yes|YES|y|Y)
      break
      ;;
    no|No|n|N|NO )
      echo "Define and configure the cluster settings in ./k8sinit before running $0."
      break
      exit 1
      ;;
   *)
     echo -en "Did you define and configure the cluster settings in ./k8sinit? (yes/no) \n"
     ;;
esac
done

ROOT_DIR=`pwd`
source ${ROOT_DIR}/k8sinit
function validate_input() {
 if [ "\${${1}}" == "" ]; then
   echo "Please initialize the value of $1 and try"
   exit 1
 fi
}

validate_input MASTER_HOST
validate_input ETCD_ENDPOINTS
validate_input K8S_SERVICE_IP
validate_input DNS_SERVICE_IP
validate_input ADVERTISE_IP

# Configuring flanneld for Container Networking
echo "Customizing flanneld for networking of containers"
systemctl enable flanneld
cp -f templates/common/flannel_options.env ${ROOT_DIR}/flannel_options.env
sed -i "s#\${ADVERTISE_IP}#${ADVERTISE_IP}#g; s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${ROOT_DIR}/flannel_options.env
if [ ! -d /etc/flannel ]; then
  mkdir -p /etc/flannel
fi
#if [ -f /etc/flannel/options.env ]; then
  mv ${ROOT_DIR}/flannel_options.env /etc/flannel/options.env
#fi
if [ ! -d /etc/systemd/system/flanneld.service.d ]; then
  mkdir -p /etc/systemd/system/flanneld.service.d
  cp -f templates/common/flanneld_svc_ExecStartPre-Symlink.conf /etc/systemd/system/flanneld.service.d/ExecStartPre-Symlink.conf
fi

# Configuring docker for Container Runtime
echo "Customizing docker for container runtime"
systemctl enable docker
if [ ! -d /etc/systemd/system/docker.service.d ]; then
  mkdir -p /etc/systemd/system/docker.service.d
  #cp -f templates/common/docker_svc_flannel.conf /etc/systemd/system/docker.service.d/40-flannel.conf
fi
if [ ! -d /etc/kubernetes/cni ]; then
  mkdir -p /etc/kubernetes/cni
  cp -f templates/common/cni_docker_options_cni.env /etc/kubernetes/cni/docker_options_cni.env
fi
if [ ! -d /etc/kubernetes/cni/net.d ]; then
  mkdir -p /etc/kubernetes/cni/net.d 
  cp -f templates/common/cni_net.d_flannel.conf /etc/kubernetes/cni/net.d/10-flannel.conf
fi

# Configuring kubelet
echo "Configuring kubelet"
cp -f templates/worker/kubelet.service ${ROOT_DIR}/kubelet.service
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g; s#\${ADVERTISE_IP}#${ADVERTISE_IP}#g" ${ROOT_DIR}/kubelet.service
sed -i "s#\${DNS_SERVICE_IP}#${DNS_SERVICE_IP}#g; s#\${NETWORK_PLUGIN}#cni#g" ${ROOT_DIR}/kubelet.service
#if [ ! -f /etc/systemd/system/kubelet.service ]; then
  mv ${ROOT_DIR}/kubelet.service /etc/systemd/system/kubelet.service
#fi  
systemctl enable kubelet
systemctl daemon-reload

if [ ! -d /etc/kubernetes/manifests ]; then
  mkdir -p /etc/kubernetes/manifests
  chmod 755 /etc/kubernetes/manifests
  chown root:root /etc/kubernetes/manifests
fi

# Configuring kube-proxy
echo "Installing manifests for kube-proxy"
cp -f templates/worker/kube-proxy.yaml ${ROOT_DIR}/kube-proxy.yaml
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/kube-proxy.yaml
mv ${ROOT_DIR}/kube-proxy.yaml /etc/kubernetes/manifests/kube-proxy.yaml

# Installing kubectl
KUBECTL_VERSION=${K8S_VERSION/_*/}
if [ ! -d /opt/bin ]; then
  mkdir -p /opt/bin
fi
if [ ! -f /opt/bin/kubectl ]; then
  pushd /opt/bin
  curl -O https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl
  if [ $? -ne 0 ]; then
    echo "ERROR: There was a problem while downloading kubectl binary"
  fi
  chmod +x kubectl
  popd
fi
cp -f templates/worker/kubeconfig.yaml /etc/kubernetes/worker-kubeconfig.yaml
sed -i "s#\${MASTER_HOST}#${MASTER_HOST}#g" /etc/kubernetes/worker-kubeconfig.yaml
if [ ! -d ~/.kube ]; then
  mkdir -p ~/.kube
fi
cp -f /etc/kubernetes/worker-kubeconfig.yaml ~/.kube/config

# Reloading services
systemctl daemon-reload
systemctl restart flanneld
if [ $? -ne 0 ]; then
  echo "ERROR: There is a problem in starting/restarting flanneld"
  systemctl status flanneld
  exit 1
fi
systemctl restart docker
if [ $? -ne 0 ]; then
  echo "ERROR: There is a problem in starting/restarting docker"
  systemctl status docker
  exit 1
fi
systemctl restart kubelet
if [ $? -ne 0 ]; then
  echo "ERROR: There is a problem in starting/restarting kubelet"
  systemctl status kubelet
  exit 1
fi
