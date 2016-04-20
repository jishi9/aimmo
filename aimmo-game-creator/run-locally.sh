#!/usr/bin/env bash

set -eu

# Based on http://kubernetes.io/docs/getting-started-guides/docker/

# Kubernetes version
K8S_VERSION="1.2.0"

function run_quietly() {
	"$@" > /dev/null
}

function error() {
	echo "$@"
	exit 1
}

function error_cat() {
	cat
	exit 1
}

#### Check dependencies

run_quietly which kubectl ||
	error "Please install kubectl with the version corresponding to the defined value K8S_VERSION=${K8S_VERSION}"


kubectl version --client=true | grep -q -- "$K8S_VERSION" ||
	error 'The version of kubectl does not match the defined value K8S_VERSION=${K8S_VERSION}'


run_quietly which docker ||
	error 'Please install docker: https://docs.docker.com/engine/installation/'


run_quietly docker info || error_cat <<EOF

*** Common problems ***

* The docker daemon is not running:
Linux:
  See https://docs.docker.com/engine/admin/configuring/

Mac:
  See https://docs.docker.com/engine/installation/mac/
  This probably will involve running commands like the following:
    # First time only. Create a docker engine called 'c4l'
    docker-machine create --driver virtualbox c4l  

    # Setup environment
    eval \$(docker-machine env c4l)

    # Check that daemon is setup correctly
    docker info


# Host is not running:
You probably have your environment setup against an old docker-machine instance, try running:
	eval \$(docker-machine env c4l)

If this command fails, then (assuming you have already created this docker-machine):
	docker-machine start c4l
EOF


#### Kubernetes functions

function remove-containers() {
	containerids="$(cat)"

	echo "$containerids" | xargs docker kill
	echo "$containerids" | xargs docker rm
}


function stop-kubernetes() {
	echo "Stopping kubernetes"

	# Kill master
	docker ps -q --filter name=kubelet | remove-containers

	# Kill rest
	docker ps -q --filter name=k8s_ | remove-containers

	echo "Stopped any running kubernetes containers"
}

function mac-only-setup-forwarding() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Make API server locally accessible
        echo "Forwarding docker port 8080"
	    docker-machine ssh `docker-machine active` -f -N -L 8080:localhost:8080
	fi
}
function start-kubernetes() {
	# Setup and start a local Kubernetes pod
	echo "Setting up Kubernetes"
	docker run \
	    --volume=/:/rootfs:ro \
	    --volume=/sys:/sys:ro \
	    --volume=/var/lib/docker/:/var/lib/docker:rw \
	    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
	    --volume=/var/run:/var/run:rw \
	    --net=host \
	    --pid=host \
	    --privileged=true \
	    --name=kubelet \
	    -d \
	    gcr.io/google_containers/hyperkube-amd64:v${K8S_VERSION} \
	    /hyperkube kubelet \
	        --containerized \
	        --hostname-override="127.0.0.1" \
	        --address="0.0.0.0" \
	        --api-servers=http://localhost:8080 \
	        --config=/etc/kubernetes/manifests \
	        --cluster-dns=10.0.0.10 \
	        --cluster-domain=cluster.local \
	        --allow-privileged=true --v=2

    mac-only-setup-forwarding

	echo "Waiting for kubernetes to start, this may take several minutes"
	while ! kubectl get nodes ; do
		sleep 20
	done

	echo "Kubernetes started"

}

stop-kubernetes

start-kubernetes
