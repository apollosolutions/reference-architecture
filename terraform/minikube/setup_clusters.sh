#/bin/bash
set -euxo pipefail

if [[ $(which kubectl) == "" ]]; then
  echo "kubectl not installed"
  exit 1
fi

if [[ $(which minikube) == "" ]]; then
  echo "minikube not installed"
  exit 1
fi

if [[ $(which kubectx) == "" ]]; then
  echo "kubectx not installed"
  exit 1
fi

environment_setup(){
    echo "Configuring Kubeconfig for minikube..."
    minikube addons enable ingress
    kubectx minikube

    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl create serviceaccount -n "monitoring" "metrics-writer" --dry-run=client -o yaml | kubectl apply -f -
}

environment_setup