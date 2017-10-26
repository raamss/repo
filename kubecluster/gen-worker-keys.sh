#!/bin/bash
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage:"
  echo "Note: Update the cluster settings in k8sinit before running $0"
  echo "$0 WORKER_NODE_IP WORKER_NODE_FQDN"
  exit 0
fi

if [ $# -lt 2 ]; then
  echo "Usage:"
  echo "Note: Update the cluster settings in k8sinit before running $0"
  echo "$0 WORKER_NODE_IP WORKER_NODE_FQDN"
  exit 1 
fi

if [ ${1} != "" ]; then
  x=$( echo ${1} | awk -F "." "{ if ( NF != 4 ) { print \$0 \" is an invalid value\" }; for(i=1; i<=NF; i++) { if ( \$i !~ /^[0-9]+\$/ ) { print \$i \" is not a valid value in \" \$0 }}}" )
  if [ "$x" != "" ]; then
    echo -en "Will exit now.\n\r $x \n"
    exit 1
  fi
fi
source ./k8sinit
ROOT_DIR=`pwd`
SSL_CERT_DIR="${ROOT_DIR}/certs/${K8S_CLUSTER_ID}-`hostname`"

if [ ! -d ${SSL_CERT_DIR} ]; then 
  mkdir -p ${SSL_CERT_DIR}
fi

function gen_workernode_keys() {
  echo "Generating SSL Keys for Worker node $1 ie., $2..."
  openssl genrsa -out ${SSL_CERT_DIR}/${2}-worker-key.pem 2048
  WORKER_IP=${1} openssl req -new -key ${SSL_CERT_DIR}/${2}-worker-key.pem -out ${SSL_CERT_DIR}/${2}-worker.csr -subj "/CN=${2}" -config  templates/worker/openssl.cnf
  if [ -f ${SSL_CERT_DIR}/ca.pem ]; then
    WORKER_IP=${1} openssl x509 -req -in ${SSL_CERT_DIR}/${2}-worker.csr -CA ${SSL_CERT_DIR}/ca.pem -CAkey ${SSL_CERT_DIR}/ca-key.pem -CAcreateserial -out ${SSL_CERT_DIR}/${2}-worker.pem -days 365 -extensions v3_req -extfile templates/worker/openssl.cnf
    echo "Worker node keys are signed by ${SSL_CERT_DIR}/ca.pem."
  else
    WORKER_IP=${1} openssl x509 -req -in ${SSL_CERT_DIR}/${2}-worker.csr -CA /etc/kubernetes/ssl/ca.pem -CAkey /etc/kubernetes/ssl/ca-key.pem -CAcreateserial -out ${SSL_CERT_DIR}/${2}-worker.pem -days 365 -extensions v3_req -extfile templates/worker/openssl.cnf
    echo "Worker node keys are signed by /etc/kubernetes/ssl/ca.pem."
  fi
}

# Invoke as "gen_workernode_keys WORKER_IP WORKER_FQDN"
gen_workernode_keys $1 $2 
for i in 1 2 3 4 5
do
  echo "INFO: Make sure to copy the ${SSL_CERT_DIR}/${2}-worker*.pem to worker node's /etc/kubernetes/ssl directory, "
  echo "      and corresponding ca.pem before setting up worker node"
  sleep 5s
done
