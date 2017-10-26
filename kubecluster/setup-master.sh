#!/bin/bash
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage:"
  echo "Update the cluster settings in k8sinit before running $0"
  echo "$0"
  exit 0
fi

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
SSL_CERT_DIR="${ROOT_DIR}/certs/${K8S_CLUSTER_ID}-`hostname`"

if [ ! -d ${SSL_CERT_DIR} ]; then 
  mkdir -p ${SSL_CERT_DIR}
fi

function validate_input() {
 if [ "\${${1}}" == "" ]; then
   echo "Please initialize the value of $1 in ${ROOT_DIR}/k8sinit and try"
   exit 1
 fi
}

validate_input MASTER_HOST
validate_input ETCD_ENDPOINTS
validate_input K8S_SERVICE_IP
validate_input DNS_SERVICE_IP
validate_input ADVERTISE_IP

function gen_master_keys() {
  echo "Generating Certificate Authority Keys..."
  if [ ! -f "/etc/kubernetes/ssl/ca-key.pem" ] || [ ! -f "/etc/kubernetes/ssl/ca.pem" ]; then
    openssl genrsa -out ${SSL_CERT_DIR}/ca-key.pem 2048
    openssl req -x509 -new -nodes -key ${SSL_CERT_DIR}/ca-key.pem -days 10000 -out ${SSL_CERT_DIR}/ca.pem -subj "/CN=${K8S_CLUSTER_ID}-kube-ca"
  else
    echo "Skipped generating CA Keys...which is already available in /etc/kubernetes/ssl"
  fi

  echo "Generating SSL Keys for API Server..."
  cp -f templates/master/openssl.cnf  ${ROOT_DIR}/master-openssl.cnf
  sed -i "s#\${K8S_SERVICE_IP}#${K8S_SERVICE_IP}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/master-openssl.cnf
  if [ "${MASTER_DNS_NAME}" == "" ]; then
    sed -i "/\${MASTER_DNS_NAME}/d" ${ROOT_DIR}/master-openssl.cnf
  fi
  if [ "${MASTER_LOADBALANCER_IP}" == "" ]; then
    sed -i "/\${MASTER_LOADBALANCER_IP}/d" ${ROOT_DIR}/master-openssl.cnf
  fi
  if [ ! -f "/etc/kubernetes/ssl/apiserver-key.pem" ] || [ ! -f "/etc/kubernetes/ssl/apiserver.pem" ]; then
    openssl genrsa -out ${SSL_CERT_DIR}/apiserver-key.pem 2048
    openssl req -new -key ${SSL_CERT_DIR}/apiserver-key.pem -out ${SSL_CERT_DIR}/apiserver.csr -subj "/CN=${K8S_CLUSTER_ID}-kube-apiserver" -config ${ROOT_DIR}/master-openssl.cnf
    openssl x509 -req -in ${SSL_CERT_DIR}/apiserver.csr -CA ${SSL_CERT_DIR}/ca.pem -CAkey ${SSL_CERT_DIR}/ca-key.pem -CAcreateserial -out ${SSL_CERT_DIR}/apiserver.pem -days 365 -extensions v3_req -extfile ${ROOT_DIR}/master-openssl.cnf
  else
    echo "Skipped generating API server keys...which is already available in /etc/kubernetes/ssl"
  fi

  echo "Generating SSL keys for Cluster Admin..."
  if [ ! -f "/etc/kubernetes/ssl/admin-key.pem" ] || [ ! -f "/etc/kubernetes/ssl/admin.pem" ]; then
    openssl genrsa -out ${SSL_CERT_DIR}/admin-key.pem 2048
    openssl req -new -key ${SSL_CERT_DIR}/admin-key.pem -out ${SSL_CERT_DIR}/admin.csr -subj "/CN=${K8S_CLUSTER_ID}-kube-admin"
    openssl x509 -req -in ${SSL_CERT_DIR}/admin.csr -CA ${SSL_CERT_DIR}/ca.pem -CAkey ${SSL_CERT_DIR}/ca-key.pem -CAcreateserial -out ${SSL_CERT_DIR}/admin.pem -days 365
  else
    echo "Skipped generating Admin keys...which is already available in /etc/kubernetes/ssl"
  fi
  rm -f ${ROOT_DIR}/master-openssl.cnf
}

# Configuring SSL for Container Security
gen_master_keys

if [ ! -d /etc/kubernetes/ssl ]; then
  mkdir -p /etc/kubernetes/ssl
  chmod 600 /etc/kubernetes/ssl
  chown root:root /etc/kubernetes/ssl
fi

if [ ! -f /etc/kubernetes/ssl/ca-key.pem ]; then
  cp -f ${SSL_CERT_DIR}/ca-key.pem /etc/kubernetes/ssl
fi
if [ ! -f /etc/kubernetes/ssl/ca.pem ]; then
  cp -f ${SSL_CERT_DIR}/ca.pem /etc/kubernetes/ssl
fi
if [ ! -f /etc/kubernetes/ssl/apiserver-key.pem ]; then
  cp -f ${SSL_CERT_DIR}/apiserver-key.pem /etc/kubernetes/ssl
fi
if [ ! -f /etc/kubernetes/ssl/apiserver.pem ]; then
  cp -f ${SSL_CERT_DIR}/apiserver.pem /etc/kubernetes/ssl
fi
if [ ! -f /etc/kubernetes/ssl/admin-key.pem ]; then
  cp -f ${SSL_CERT_DIR}/admin-key.pem /etc/kubernetes/ssl
fi
if [ ! -f /etc/kubernetes/ssl/admin.pem ]; then
  cp -f ${SSL_CERT_DIR}/admin.pem /etc/kubernetes/ssl
fi
chmod 600 /etc/kubernetes/ssl/*
chown root:root /etc/kubernetes/ssl/*

# Configuring etcd for Service Discovery for Containers
echo "Customizing etcd for service discovery of containers"
cp -f templates/master/etcd2_svc_listen-address.conf ${ROOT_DIR}/listen-address.conf
sed -i "s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/listen-address.conf
if [ ! -d /etc/systemd/system/etcd2.service.d ]; then
  mkdir -p /etc/systemd/system/etcd2.service.d
fi
mv ${ROOT_DIR}/listen-address.conf /etc/systemd/system/etcd2.service.d/10-listen-address.conf
systemctl enable etcd2

# Configuring flanneld for Container Networking
echo "Customizing flanneld for networking of containers"
cp -f templates/common/flannel_options.env ${ROOT_DIR}/flannel_options.env
sed -i "s#\${ADVERTISE_IP}#${ADVERTISE_IP}#g; s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${ROOT_DIR}/flannel_options.env 
if [ ! -d /etc/flannel ]; then
  mkdir -p /etc/flannel
fi
#if [ ! -f /etc/flannel/options.env ]; then
  mv ${ROOT_DIR}/flannel_options.env /etc/flannel/options.env
#fi
rm -f ${ROOT_DIR}/flannel_options.env
if [ ! -d /etc/systemd/system/flanneld.service.d ]; then
  mkdir -p /etc/systemd/system/flanneld.service.d
  cp -f templates/common/flanneld_svc_ExecStartPre-Symlink.conf /etc/systemd/system/flanneld.service.d/ExecStartPre-Symlink.conf
fi
systemctl enable flanneld

# Configuring docker for Container Runtime
echo "Customizing docker for container runtime"
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
systemctl enable docker

# Update etcd cluster
systemctl enable etcd2
systemctl restart etcd2
if [ $? -ne 0 ]; then
  echo "ERROR: There is a problem in starting/restarting etcd cluster"
  systemctl status etcd2
  exit 1
fi
curl -X PUT -d "value={\"Network\":\"${POD_NETWORK}\",\"Backend\":{\"Type\":\"vxlan\"}}" "http://127.0.0.1:2379/v2/keys/coreos.com/network/config"
if [ $? -ne 0 ]; then
  echo "ERROR: There is a problem in updating the network configuration in etcd cluster"
  exit 1
fi

# Configuring kubelet
echo "Configuring kubelet"
cp -f templates/master/kubelet.service ${ROOT_DIR}/kubelet.service
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g; s#\${ADVERTISE_IP}#${ADVERTISE_IP}#g" ${ROOT_DIR}/kubelet.service
sed -i "s#\${DNS_SERVICE_IP}#${DNS_SERVICE_IP}#g; s#\${NETWORK_PLUGIN}#cni#g" ${ROOT_DIR}/kubelet.service
mv ${ROOT_DIR}/kubelet.service /etc/systemd/system/kubelet.service
systemctl enable kubelet
systemctl daemon-reload

if [ ! -d /etc/kubernetes/manifests ]; then
  mkdir -p /etc/kubernetes/manifests
  chmod 755 /etc/kubernetes/manifests
  chown root:root /etc/kubernetes/manifests
fi

# Configuring kube-apiserver
echo "Installing manifests for kube-apiserver"
cp -f templates/master/kube-apiserver.yaml ${ROOT_DIR}/kube-apiserver.yaml
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g; s#\${ADVERTISE_IP}#${ADVERTISE_IP}#g" ${ROOT_DIR}/kube-apiserver.yaml
sed -i "s#\${SERVICE_IP_RANGE}#${SERVICE_IP_RANGE}#g; s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${ROOT_DIR}/kube-apiserver.yaml
mv ${ROOT_DIR}/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

# Configuring kube-proxy
echo "Installing manifests for kube-proxy"
cp -f templates/master/kube-proxy.yaml ${ROOT_DIR}/kube-proxy.yaml
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/kube-proxy.yaml
mv ${ROOT_DIR}/kube-proxy.yaml /etc/kubernetes/manifests/kube-proxy.yaml

# Configuring kube-controller-manager
echo "Installing manifests for kube-controller-manager"
cp -f templates/master/kube-controller-manager.yaml ${ROOT_DIR}/kube-controller-manager.yaml
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/kube-controller-manager.yaml
mv ${ROOT_DIR}/kube-controller-manager.yaml /etc/kubernetes/manifests/kube-controller-manager.yaml

# Configuring kube-scheduler
echo "Installing manifests for kube-scheduler"
cp -f templates/master/kube-scheduler.yaml ${ROOT_DIR}/kube-scheduler.yaml
sed -i "s#\${K8S_VERSION}#${K8S_VERSION}#g; s#\${MASTER_HOST}#${MASTER_HOST}#g" ${ROOT_DIR}/kube-scheduler.yaml
mv ${ROOT_DIR}/kube-scheduler.yaml /etc/kubernetes/manifests/kube-scheduler.yaml

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

# Adding kubeconfig 
echo "Installing kubeconfig file"
cp -f templates/master/kubeconfig ${ROOT_DIR}/kubeconfig
sed -i "s#\${MASTER_HOST}#${MASTER_HOST}#g; s#\${K8S_CLUSTER_ID}#${K8S_CLUSTER_ID}#g" ${ROOT_DIR}/kubeconfig
if [ ! -f /var/lib/kubelet/kubeconfig ]; then
  mv ${ROOT_DIR}/kubeconfig /var/lib/kubelet/kubeconfig
fi

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
