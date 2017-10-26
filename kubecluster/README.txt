Prerequisities:
---------------
This scripts are developed and tested to run Kubernetes with following requirements fulfilled

1) Base Operating System: CoreOS (Container Linux), preferably stable channel, installed to disk and user accounts setup
2) Dependencies: Static IP configured for the nodes to create Kubernetes cluster


To setup master node
---------------------
1. Clone the git repo for kubecluster, or, download and extract the kubecluster archive to designated node.
2. Define and initialize settings for Kubernetes Cluster for master node, in k8sinit.
3. Run setup-master.sh on the designated master node of Kubernetes Cluster.

To setup worker node
--------------------
A. On Master Node:
   1. Run "gen-worker-keys.sh <WorkerNode_IP> <WorkerNode_FQDN>" to generate SSL keys.
   2. Copy the generated SSL keys from master node to designated worker node.
B. On Worker Node:
   3. Clone the git repo for kubecluster, or, download and extract the kubecluster archive to designated node.
   4. Define and initialize settings for Kubernetes Cluster for worker node, in k8sinit.
   5. Run setup-worker.sh on the designated worker node of Kubernetes Cluster.
