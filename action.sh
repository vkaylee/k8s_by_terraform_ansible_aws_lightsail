#!/usr/bin/env bash
# Need tools:
needTools=()
needTools+=( terraform )
needTools+=( ansible )
needTools+=( ansible-playbook )
needTools+=( ansible-inventory )
needTools+=( kubectl )
needTools+=( jq )
needTools+=( awk )
needTools+=( grep )
needTools+=( tr )
needTools+=( wc )
for command in ${needTools[@]}; do
    if [ ! "$(command -v ${command})" ]; then
        echo "command \"${command}\" does not exist on the system"
        exit 1
    fi
done
working_dir="$(dirname $0)"
thisScriptPath="${working_dir}/$(basename "$0")"
sshKeyPath="${working_dir}/tf_k8s.pem"
# Apply lock file to avoid multiple run in the same time
# Due to the issue with terraform and ansible, ansible is depended on configuration file that is rendered by terraform
# We just allow to run only one process at once
# Refer: https://www.putorius.net/lock-files-bash-scripts.html
internalCallMark="internalCallMark"
# Check the first argument to know is it called form internal?
if [[ "${internalCallMark}" != "${1}" ]]; then
    # Don't apply lock strategy for internal call 
    # Check is Lock File exists, if not create it and set trap on exit
    if { set -C; 2>/dev/null > "${thisScriptPath}.lock"; }; then
        trap "rm -f ${thisScriptPath}.lock" EXIT
    else
        echo "This script is running in another process, try again later"
        exit 1
    fi
else
    # Remove the first argument
    shift 1
fi

function sigint_func()
{
    exit 0
}
trap sigint_func SIGINT

kubectl_func(){
    kubectl --kubeconfig="${working_dir}/kubeconfig" "$@"
    return $?
}

terraform_func(){
    terraform -chdir="${working_dir}" "$@"
    return $?
}

ansible_playbook_func(){
    ANSIBLE_CONFIG="${working_dir}/ansible.cfg" ansible-playbook --flush-cache "$@"
    return $?
}

ansible_inventory_func(){
    ANSIBLE_CONFIG="${working_dir}/ansible.cfg" ansible-inventory "$@"
    return $?
}

main(){
    case "${1}" in
        init)
            shift 1
            # Check current infrastructure
            if [[ -n "$(terraform_func state list)" ]]; then
                echo "Cluster is existed"
                return
            fi

            # Terraform init
            if ! terraform_func init; then
                echo "Check your terraform configuration and try again"
                return 1
            fi

            # Create infrastructure
            local count
            count=1
            while true; do
                if terraform_func apply -auto-approve; then
                    break 1
                fi
                # Give it 3 times to try
                if (( $(echo "${count} >= 3" | bc -l) )); then
                    return 1
                fi
                
                ((count++))
                sleep 1
            done
            
            # Install cluster
            local count
            count=1
            while true; do
                if ansible_playbook_func "${working_dir}/k8s.playbook.yml" --limit 'masters,master_lbs,workers,worker_lbs'; then
                    break 1
                fi
                # Give it 3 times to try
                if (( $(echo "${count} >= 3" | bc -l) )); then
                    return 1
                fi
                
                ((count++))
                sleep 1
            done

            kubectl_func get nodes -o wide
            return $?
        ;;
        scale)
            shift 1
            # Get current instances
            local master_count
            master_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.master\[)\d+" | wc -l)
            local master_lb_count
            master_lb_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.master_lb\[)\d+" | wc -l)
            local worker_count
            worker_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.worker\[)\d+" | wc -l)
            local worker_lb_count
            worker_lb_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.worker_lb\[)\d+" | wc -l)
            local currentTerraformVarOptions
            currentTerraformVarOptions="-var="master_count=${master_count}" -var="master_lb_count=${master_lb_count}" -var="worker_count=${worker_count}" -var="worker_lb_count=${worker_lb_count}""

            local nodeRole
            # By default: nodeRole is worker
            nodeRole="worker"
            if [[ "${2}" == "master" ]]; then
                nodeRole="master"
            elif [[ "${2}" == "worker_lb" ]]; then
                nodeRole="worker_lb"
            fi

            case "${1}" in
                up)
                    shift 1
                    local ansibleLimit
                    ansibleLimit="master_1,worker_lbs,worker_$((worker_count +1))"
                    local terraformVarOptions
                    terraformVarOptions="${currentTerraformVarOptions} -var="worker_count=$((worker_count+1))""
                    if [[ "${nodeRole}" == "master" ]]; then
                        # Must add master_lb to update loadbalancing configuration
                        ansibleLimit="master_1,master_lb_1,master_$((master_count +1))"
                        terraformVarOptions="${currentTerraformVarOptions} -var="master_count=$((master_count+1))""
                    elif [[ "${nodeRole}" == "worker_lb" ]]; then
                        ansibleLimit="worker_lb_$((worker_lb_count +1))"
                        terraformVarOptions="${currentTerraformVarOptions} -var="worker_lb_count=$((worker_lb_count+1))""
                    fi
                    # Scale up infrastructure
                    local count
                    count=1
                    while true; do
                        if terraform_func apply -auto-approve ${terraformVarOptions}; then
                            sleep 15
                            break 1
                        fi
                        # Give it 3 times to try
                        if (( $(echo "${count} >= 3" | bc -l) )); then
                            return 1
                        fi
                        
                        ((count++))
                        sleep 1
                    done

                    # Run ansible playbook but limit to:
                    # master_1: get join command
                    # The new node: install components and join
                    # Just run tasks with tag addNode
                    local count
                    count=1
                    while true; do
                        if ! ansible_playbook_func "${working_dir}/k8s.playbook.yml" --limit "${ansibleLimit}" --tags addNode; then
                            local count1
                            count1=1
                            while true; do
                                if terraform_func apply -auto-approve ${currentTerraformVarOptions}; then
                                    break 1
                                fi
                                # Give it 3 times to try
                                if (( $(echo "${count1} >= 3" | bc -l) )); then
                                    return 1
                                fi
                                
                                ((count1++))
                                sleep 1
                            done
                        fi
                        # Give it 3 times to try
                        if (( $(echo "${count} >= 3" | bc -l) )); then
                            return 1
                        fi
                        
                        ((count++))
                        sleep 1
                    done
                    sleep 15
                    kubectl_func get nodes -o wide
                    return $?
                ;;
                down)
                    shift 1
                    # TODO: Issue when scale down master, due to the issue with the ETCD node in master
                    if [[ "${nodeRole}" == "master" ]]; then
                        echo "Scale ${nodeRole} down is not allowed this time"
                        return 1
                    fi
                    
                    # Get current instances
                    local instance_count
                    instance_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.${nodeRole}\[)\d+" | wc -l)
                    if (( $instance_count <= 1 )); then
                        echo "The ${nodeRole} must have at least one node"
                        return 1
                    fi
                    
                    local private_ip
                    private_ip=$(ansible_inventory_func --host "${nodeRole}_${instance_count}" | jq .private_ip | tr -d '"')

                    if [[ "${nodeRole}" == "worker" ]]; then
                        local node_name
                        while [[ -z "${node_name}" ]]; do
                            node_name=$(kubectl_func get node -o wide | grep "${private_ip}" | awk '{ print $1 }')
                            if [[ -n "${node_name}" ]]; then
                                break 1
                            fi
                            
                            # when the node is in inventory but not in kubernetes nodes
                            # Don't forget to put internalCallMark to notify this call is from internal
                            eval "${working_dir}/$(basename "$0") ${internalCallMark} refresh"
                        done
                        

                        # Kubernetes cordon
                        kubectl_func cordon "${node_name}"
                        # Kubernetes drain
                        if kubectl_func drain "${node_name}" --ignore-daemonsets; then
                            # Kubernetes delete node
                            kubectl_func delete node "${node_name}"
                            # Scale down infrastructure
                            local terraformVarOptions
                            terraformVarOptions="${currentTerraformVarOptions} -var="worker_count=$((worker_count-1))""
                            if [[ "${nodeRole}" == "master" ]]; then
                                terraformVarOptions="${currentTerraformVarOptions} -var="master_count=$((master_count-1))""
                            fi
                            local count
                            count=1
                            while true; do
                                if terraform_func apply -auto-approve ${terraformVarOptions}; then
                                    if ansible_playbook_func "${working_dir}/k8s.playbook.yml" --limit "worker_lbs" --tags deleteNode; then
                                        break 1
                                    fi
                                fi
                                # Give it 3 times to try
                                if (( $(echo "${count} >= 3" | bc -l) )); then
                                    return 1
                                fi
                                
                                ((count++))
                                sleep 1
                            done
                        fi

                        kubectl_func get nodes -o wide
                        return $?
                    elif [[ "${nodeRole}" == "worker_lb" ]]; then
                        # Scale down infrastructure
                        local terraformVarOptions
                        terraformVarOptions="${currentTerraformVarOptions} -var="worker_lb_count=$((worker_lb_count-1))""
                        local count
                        count=1
                        while true; do
                            if terraform_func apply -auto-approve ${terraformVarOptions}; then
                                break 1
                            fi
                            # Give it 3 times to try
                            if (( $(echo "${count} >= 3" | bc -l) )); then
                                return 1
                            fi
                            
                            ((count++))
                            sleep 1
                        done
                    else
                        return 1
                    fi
                ;;
                *)
                    echo "Please choose:"
                    echo "up"
                    echo "down"
                    exit 1
                ;;
            esac
        ;;

        destroy)
            shift 1
            local count
            count=1
            while true; do
                if terraform_func apply -auto-approve -destroy; then
                    # Remove kubeconfig, created by ansible
                    rm -f "${working_dir}/kubeconfig"
                    # Remove key
                    rm -f ${sshKeyPath}*

                    break 1
                fi
                # Give it 3 times to try
                if (( $(echo "${count} >= 3" | bc -l) )); then
                    return 1
                fi
                
                ((count++))
                sleep 1
            done
            return 0
        ;;

        refresh)
            shift 1
            local count
            count=1
            while true; do
                if ansible_playbook_func "${working_dir}/k8s.playbook.yml"; then
                    break 1
                fi
                # Give it 3 times to try
                if (( $(echo "${count} >= 3" | bc -l) )); then
                    return 1
                fi
                
                ((count++))
                sleep 1
            done
            return 0
        ;;

        *)
            local thisScriptPath
            thisScriptPath="${working_dir}/$(basename "$0")"
            local actions
            actions=()
            #####################################
            #####################################
            #### Declare the list of actions ####
            actions+=("init")
            actions+=("scale up")
            actions+=("scale down")
            actions+=("scale up master")
            actions+=("scale up worker_lb")
            actions+=("scale down worker_lb")
            actions+=("refresh")
            actions+=("destroy")
            #####################################
            #####################################
            #####################################
            
            declare -A actionMap
            for action in "${actions[@]}"; do
                # Replace all space to dash (-)
                actionMap["${action// /-}"]="${action}"
            done
            local actionKeys
            actionKeys=()
            for actionKey in "${!actionMap[@]}"; do
                actionKeys+=(${actionKey})
            done
            IFS=$'\n' sortedActionKeys=($(sort <<<"${actionKeys[*]}")); unset IFS
            # Load lib for selection feature
            source "$working_dir/shell_libs/bash_selection_lib.sh"
            selected_item=0
            run_menu "$selected_item" "${sortedActionKeys[@]}"
            menu_result="$?"

            echo

            local actionKeyChose
            actionKeyChose="${sortedActionKeys[${menu_result}]}"
            if [[ -z "${actionKeyChose}" ]]; then
                echo "Error"
                return 1
            fi
            
            echo "You chose: ${actionMap[${actionKeyChose}]}"

            # Don't forget to put internalCallMark to notify this call is from internal
            eval "${thisScriptPath} ${internalCallMark} ${actionMap[${actionKeyChose}]}"
            return $?
        ;;
    esac
    return 0
}

main "${@}"
