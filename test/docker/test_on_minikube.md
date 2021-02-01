### Purpose

This README provides basic understanding on how to run lockers tests in a minikube cluster.

### How to run tests in Minikube ?

1. Minikube must be installed and running. Get OS specific installation process from
   their [official website](https://minikube.sigs.k8s.io/docs/start/). Once installed,
   use `minikube start` to start up the cluster and you can also check the status by
   `minikube status`.
2. This repo needs to be mounted on to the K8s pod to run tests. In order to create a
   mount from host machine to K8s pod, one should mount the path to minikube first.
3. Create a mount on to minikube by doing `minikube mount <hostpath>:/lockers`.
   `hostpath` is your current location of the repo.
4. Minikube uses its own docker environment rather than the one running on host machine.
   Do `eval $(minikube docker-env)` to point your terminal to use the docker daemon
   running inside minikube and upload images to it.
5. [lockers.yaml](./lockers.yaml) contains the required configuration to create a container
   where the tests are run. Do `docker-compose <image_name> -f ./lockers.yaml build` to
   generate an image and upload it to minikube docker env.
6. The basic manifest to create a pod is located at [lockers-k8s.json](./lockers-k8s.json).
   It is configured to expose the ssh port and also to mount the lockers repo from minikube
   cluster to pod.
7. Update the `PROJECT_NAME` and `IMAGE_NAME` fields in manifest with a new project name
   and image name used in step (6) while creating it, then create a pod using `kubectl
   apply -f lockers-k8s.json`. Also change `volumes.hostpath` if configured differently
   in step (3).
8. You can check if the pod has started running using `kubectl get pod <project-name> -o
   jsonpath="{.status.phase}"`.
9. After the pod status has changed to `Running` invoke the tests using `kubectl exec
   project-name> -- bash -c 'su locker_user -c /start.sh'`.
10. Logs show if the test cases are failed/passed and also you can check the exit code of
    the script using `echo $?`.
11. Pod can be deleted using `kubectl delete pod <project-name>`.