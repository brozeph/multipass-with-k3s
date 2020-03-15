#!/bin/bash
# assumes multipass is installed: brew install multipass
# assumes kubectl is installed: brew install kubectl

# names for the VMs in the cluster (update as desired)
K3S_MASTER_VM=k3s-master
K3S_WORKER_1_VM=k3s-worker-1
K3S_WORKER_2_VM=k3s-worker-2

# settings for the master and worker nodes (update as desired)
K3S_CPUS=2
K3S_MEM=2G
K3S_DISK=4G

# configure the cluster roles using kubectl
configure_roles () {
  echo Configuring Kubernetes cluster member roles

  kubectl --kubeconfig=${KUBECONFIG} label node ${K3S_MASTER_VM} \
    node-role.kubernetes.io/master="" --overwrite=true
  
  sleep 1
  kubectl --kubeconfig=${KUBECONFIG} label node ${K3S_WORKER_1_VM} \
    node-role.kubernetes.io/node="" --overwrite=true
  
  sleep 1
  kubectl --kubeconfig=${KUBECONFIG} label node ${K3S_WORKER_2_VM} \
    node-role.kubernetes.io/node="" --overwrite=true

  # configure taint NoSchedule for master
  sleep 1
  kubectl --kubeconfig=${KUBECONFIG} taint node ${K3S_MASTER_VM} \
    node-role.kubernetes.io/master=effect:NoSchedule --overwrite=true

  # verify
  kubectl --kubeconfig=${KUBECONFIG} get nodes
}

# enable local kubectl config
enable_kubectl () {
  # ensure K3S_URL is set (for debugging purposes)
  if [ -z "$K3S_URL" ]; then
    K3S_URL="https://$(multipass info ${K3S_MASTER_VM} | \
      grep "IPv4" | \
      awk -F' ' '{print $2}'):6443"
    echo Discovered K3S Master URL: ${K3S_URL}
  fi

  # copy master kubectl config locally
  mkdir -p ${HOME}/.k3s
  multipass copy-files ${K3S_MASTER_VM}:/etc/rancher/k3s/k3s.yaml ${HOME}/.k3s/k3s.yaml

  # update the kubectl config with appropriate IP
  sed -ie s,https://127.0.0.1:6443,${K3S_URL},g ${HOME}/.k3s/k3s.yaml

  # setup for kubectl
  KUBECONFIG=${HOME}/.k3s/k3s.yaml

  # verify
  kubectl --kubeconfig=${KUBECONFIG} get nodes
}

# launch nodes
launch_nodes () {
  echo Beginning to initialize local k3s cluster...
  multipass launch --name ${K3S_MASTER_VM} \
    --cpus ${K3S_CPUS} --mem ${K3S_MEM} --disk ${K3S_DISK}
  multipass launch --name ${K3S_WORKER_1_VM} \
    --cpus ${K3S_CPUS} --mem ${K3S_MEM} --disk ${K3S_DISK}
  multipass launch --name ${K3S_WORKER_2_VM} \
    --cpus ${K3S_CPUS} --mem ${K3S_MEM} --disk ${K3S_DISK}

  # setup k3s on master node
  multipass exec ${K3S_MASTER_VM} -- /bin/bash -c \
    "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -s -"

  # wait 10 sec for k3s master to initialize (this actually might not even be needed...)
  echo "Waiting for k3s master node initialization: ${K3S_MASTER_VM}"
  sleep 10

  # determine URL of master node
  K3S_URL="https://$(multipass info ${K3S_MASTER_VM} | \
    grep "IPv4" | \
    awk -F' ' '{print $2}'):6443"
  echo Discovered K3S Master URL: ${K3S_URL}

  # determine the token of the master node
  K3S_TOKEN="$(multipass exec ${K3S_MASTER_VM} -- /bin/bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")"

  # deploy k3s on k3s worker 1
  echo "Deploying k3s on worker node ${K3S_WORKER_1_VM}"
  multipass exec ${K3S_WORKER_1_VM} -- /bin/bash -c \
    "curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_URL} sh -s -"
  
  # deploy k3s on k3s worker 2
  echo "Deploying k3s on worker node ${K3S_WORKER_2_VM}"
  multipass exec ${K3S_WORKER_2_VM} -- /bin/bash -c \
    "curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_URL} sh -s -"

  # wait for k3s workers to initialize
  echo "Waiting for k3s worker initialization: ${K3S_WORKER_1_VM} and ${K3S_WORKER_2_VM}"
  sleep 20
}

# check for --cleanup argument
if [ "$1" == "--cleanup" ]; then
  echo Beginning cleanup
  multipass stop ${K3S_MASTER_VM} ${K3S_WORKER_1_VM} ${K3S_WORKER_2_VM}
  multipass delete ${K3S_MASTER_VM} ${K3S_WORKER_1_VM} ${K3S_WORKER_2_VM}
  multipass purge

  exit 0
fi

# main
launch_nodes
enable_kubectl
configure_roles
