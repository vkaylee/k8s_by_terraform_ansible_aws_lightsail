# Kubernetes on Aws lightsail
This repo will create kubernetes cluster with some tools:
- `terraform`       The tool for provisioning infrastructure as code
- `ansible`         The tool for configuration management
- `kubeadm`         The official tool to initial kubernetes cluster
- `kubelet`         The kubelet is the primary "node agent" that runs on each node
- `containerd.io`   The container runtime
- `kubectl`         The official for interacting with the cluster
- `haproxy`         TCP loadbalancing layer 4 for masters
- `nginx`           Loadbalancing for workers
- `crictl`          The command-line interface tool for inspecting and debug container runtimes and applications on a Kubernetes node

## Get started
- Create ssh key pair
```shell
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -q -N "" -f tf_k8s
    chmod 400 tf_k8s*
```
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
```
-> tf_k8s_master_1-172.26.5.123-admin@3.1.194.104
   tf_k8s_master_2-172.26.17.207-admin@13.228.24.139
   tf_k8s_master_3-172.26.34.30-admin@13.251.60.159
   tf_k8s_master_lb_1-172.26.10.159-admin@54.254.82.210
   tf_k8s_worker_1-172.26.2.234-admin@18.139.110.19
   tf_k8s_worker_2-172.26.29.245-admin@54.179.6.254
   tf_k8s_worker_3-172.26.34.73-admin@18.141.211.57
   tf_k8s_worker_lb_1-172.26.8.148-admin@54.179.170.137
```
- Automatically install kubernetes cluster (all in one)
```shell
    ansible-playbook k8s.playbook.yml
```
- Or do step by step
```shell
    ansible-playbook k8s_components_installer.playbook.yml
    ansible-playbook k8s_cluster_initial.playbook.yml
    ansible-playbook k8s_join_masters.playbook.yml
    ansible-playbook k8s_join_workers.playbook.yml
    ansible-playbook k8s_debug_print.playbook.yml
    ansible-playbook k8s_crictl_component.playbook.yml
```