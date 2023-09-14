# Kubernetes on Aws lightsail
This repo will create kubernetes cluster with some tools:
- `terraform`       The tool for provisioning infrastructure as code
- `ansible`         The tool for configuration management
- `kubeadm`         The official tool to initial kubernetes cluster
- `kubelet`         The kubelet is the primary "node agent" that runs on each node
- `containerd.io`   The container runtime
- `kubectl`         The official tool for interacting with the cluster
- `haproxy`         TCP loadbalancing layer 4 for masters
- `nginx`           Loadbalancing for workers
- `crictl`          The command-line interface tool for inspecting and debug container runtimes and applications on a Kubernetes node

## Features
- Cilium network
- DualStack (ipv4 and ipv6)

    Add to service spec section
    ```yaml
    ipFamilyPolicy: RequireDualStack
    ipFamilies: # The order is important, the first one will be shown on the service list
    - IPv4
    - IPv6
    ```
- High available cluster with haproxy loadbalancer for masters, check stats `<loadbalancerIP>:9000/stats`
- Metrics server `kubectl top pod`, `kubectl top node`
- Ingress Nginx Controller (Support DualStack)
    ```shell
    kubectl describe svc ingress-nginx-controller -n ingress-nginx
    ```
## Get started
### Automatic feature
- `./action.sh init` Create the infrastructure and install a cluster on it
- `./action.sh scale up <master or worker or worker_lb>` Add more node to cluster, default is worker node
- `./action.sh scale down <master or worker or worker_lb>` Remove one node from cluster, default is worker node
- `./action.sh destroy` Destroy the infrastructure
- `./action.sh refresh` Keep the cluster match with the inventory
- `./action.sh` to choose among options
    
    Example options, it might have more features than the list below 
    ```shell
     -> init
        refresh
        scale-down
        scale-down-worker_lb
        scale-up
        scale-up-master
        scale-up-worker_lb
    ```
### Manual steps
- Update terraform variables in `variable.tf` as your need
- Initial terraform
```shell
    terraform init
```
- Export environment variables `TF_VAR_AWS_ACCESS_KEY` and `TF_VAR_AWS_SECRET_KEY` with your aws credential
- Overview the infrastructure
```shell
    terraform plan
```
- Provision the infrastructure
```shell
    terraform apply
```
- You can try `ssh` to the server by the `ssh.sh` tool in the working directory
```shell
    ./ssh.sh
```
Example output

     -> tf_k8s_master_1-172.26.5.123-admin@3.1.194.104
        tf_k8s_master_2-172.26.17.207-admin@13.228.24.139
        tf_k8s_master_3-172.26.34.30-admin@13.251.60.159
        tf_k8s_master_lb_1-172.26.10.159-admin@54.254.82.210
        tf_k8s_worker_1-172.26.2.234-admin@18.139.110.19
        tf_k8s_worker_2-172.26.29.245-admin@54.179.6.254
        tf_k8s_worker_3-172.26.34.73-admin@18.141.211.57
        tf_k8s_worker_lb_1-172.26.8.148-admin@54.179.170.137

- Install some ansible modules
```shell
    # Modules:
    # https://docs.ansible.com/ansible/latest/collections/kubernetes/core/k8s_module.html
    # - kubernetes.core.k8s
    # - kubernetes.core.kubectl
    # https://docs.ansible.com/ansible/latest/collections/kubernetes/core/helm_module.html
    # - kubernetes.core.helm
    # - kubernetes.core.helm_repository
    # To be sure python pip module is installed in all hosts
    ansible-galaxy collection install kubernetes.core
```
- Automatically install kubernetes cluster (all in one)
```shell
    ansible-playbook k8s.playbook.yml
```
- Or do step by step
```shell
    ansible-playbook ansible_dir/k8s_components_installer.playbook.yml
    ansible-playbook ansible_dir/k8s_cluster_initial.playbook.yml
    ansible-playbook ansible_dir/k8s_join_masters.playbook.yml
    ansible-playbook ansible_dir/k8s_join_workers.playbook.yml
    ansible-playbook ansible_dir/k8s_debug_print.playbook.yml
    ansible-playbook ansible_dir/k8s_crictl_component.playbook.yml
```

- Kubeconfig path, override in kubectl by option `--kubeconfig` or export `KUBECONFIG` environment
    - In masters: `~/.kube/config` or `/etc/kubernetes/admin.conf`
    - In local: `<this working dir>/kubeconfig` (This file is automatically created by ansible)

For example:
```shell
    kubectl --kubeconfig kubeconfig
```
Combine with getting list pods
```shell
    kubectl --kubeconfig kubeconfig get pod -A
```

- Show nodes
```shell
    kubectl get node -o wide
```

    admin@ip-172-26-15-147:~$ kubectl get nodes -o wide
    NAME               STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION          CONTAINER-RUNTIME
    ip-172-26-14-179   Ready    <none>          16m   v1.27.4   172.26.14.179   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22
    ip-172-26-15-147   Ready    control-plane   19m   v1.27.4   172.26.15.147   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22
    ip-172-26-20-106   Ready    control-plane   17m   v1.27.4   172.26.20.106   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22
    ip-172-26-23-216   Ready    <none>          16m   v1.27.4   172.26.23.216   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22
    ip-172-26-34-52    Ready    control-plane   18m   v1.27.4   172.26.34.52    <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22
    ip-172-26-41-31    Ready    <none>          16m   v1.27.4   172.26.41.31    <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-17-cloud-amd64   containerd://1.6.22

- Debug pods, containers
```shell
    sudo crictl pods # list all pods
    sudo crictl ps # list all containers
```
Example output on masters

    admin@ip-172-26-20-106:~$ sudo crictl pods
    POD ID              CREATED             STATE               NAME                                       NAMESPACE           ATTEMPT             RUNTIME
    bdd8ce425de84       14 minutes ago      Ready               etcd-ip-172-26-20-106                      kube-system         0                   (default)
    6fcaa562f2ddd       14 minutes ago      Ready               kube-proxy-2bhxq                           kube-system         0                   (default)
    de705883a9e0e       14 minutes ago      Ready               calico-node-hjp28                          kube-system         0                   (default)
    4e7e8eddda845       14 minutes ago      Ready               kube-scheduler-ip-172-26-20-106            kube-system         0                   (default)
    7db3bb8b8d5c6       14 minutes ago      Ready               kube-controller-manager-ip-172-26-20-106   kube-system         0                   (default)
    cae651ea208d8       14 minutes ago      Ready               kube-apiserver-ip-172-26-20-106            kube-system         0                   (default)
    admin@ip-172-26-20-106:~$ sudo crictl ps
    CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD
    8a218a6da0a58       8065b798a4d67       13 minutes ago      Running             calico-node               0                   de705883a9e0e       calico-node-hjp28
    f3490a85c47b9       6848d7eda0341       14 minutes ago      Running             kube-proxy                0                   6fcaa562f2ddd       kube-proxy-2bhxq
    2dce4705141eb       86b6af7dd652c       14 minutes ago      Running             etcd                      0                   bdd8ce425de84       etcd-ip-172-26-20-106
    64ec890777564       e7972205b6614       14 minutes ago      Running             kube-apiserver            1                   cae651ea208d8       kube-apiserver-ip-172-26-20-106
    a690929230cf9       f466468864b7a       15 minutes ago      Running             kube-controller-manager   0                   7db3bb8b8d5c6       kube-controller-manager-ip-172-26-20-106
    4a6d5a9debd2d       98ef2570f3cde       15 minutes ago      Running             kube-scheduler            0                   4e7e8eddda845       kube-scheduler-ip-172-26-20-106

Example output on workers

    admin@ip-172-26-14-179:~$ sudo crictl pods
    POD ID              CREATED             STATE               NAME                NAMESPACE           ATTEMPT             RUNTIME
    ea15d537a319c       15 minutes ago      Ready               kube-proxy-p6tfm    kube-system         0                   (default)
    17cc51e48a59d       15 minutes ago      Ready               calico-node-nh8sx   kube-system         0                   (default)
    admin@ip-172-26-14-179:~$ sudo crictl ps
    CONTAINER           IMAGE               CREATED             STATE               NAME                ATTEMPT             POD ID              POD
    aeda596ff8753       8065b798a4d67       14 minutes ago      Running             calico-node         0                   17cc51e48a59d       calico-node-nh8sx
    0209c14bb4cba       6848d7eda0341       15 minutes ago      Running             kube-proxy          0                   ea15d537a319c       kube-proxy-p6tfm
