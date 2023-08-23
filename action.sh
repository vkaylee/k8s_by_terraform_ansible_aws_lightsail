#!/usr/bin/env bash
# Need tools:
needTools=()
needTools+=( terraform )
needTools+=( ansible )
needTools+=( ansible-playbook )
needTools+=( ansible-inventory )
needTools+=( kubectl )
needTools+=( ssh-keygen )
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

function sigint_func()
{
    exit 0
}
trap sigint_func SIGINT
working_dir="$(dirname $0)"

kubectl_func(){
    kubectl --kubeconfig="${working_dir}/kubeconfig" "$@"
    return $?
}

terraform_func(){
    terraform -chdir="${working_dir}" "$@"
    return $?
}

ANSIBLE_CONFIG="${working_dir}/ansible.cfg"

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

            # Create key
            ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -q -N "" -f "${working_dir}/tf_k8s"
            chmod 400 "${working_dir}/tf_k8s"*
            # Create infrastructure
            if terraform_func apply -auto-approve; then
                sleep 15
                local count
                count=1
                while true; do
                    if ansible-playbook -i "${working_dir}/ansible.inventory.cfg" "${working_dir}/k8s.playbook.yml" --limit 'masters,master_lbs,workers,worker_lbs'; then
                        break 1
                    fi
                    sleep 1
                done
                # Give it 3 times to try
                if (( $(echo "${count} >= 3" | bc -l) )); then
                    return 1
                fi
                
                ((count++))
                # Get nodes
                kubectl_func get nodes -o wide
                return 0
            fi
            return 1
        ;;
        scale)
            shift 1
            # Get current instances
            local master_count
            master_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.master\[)\d+" | wc -l)
            local worker_count
            worker_count=$(terraform_func state list | grep -oP "(?<=aws_lightsail_instance.worker\[)\d+" | wc -l)
            local currentTerraformVarOptions
            currentTerraformVarOptions="-var="master_count=${master_count}" -var="worker_count=${worker_count}""

            local nodeRole
            # By default: nodeRole is worker
            nodeRole="worker"
            if [[ "${2}" == "master" ]]; then
                nodeRole="master"
            fi

            case "${1}" in
                up)
                    shift 1
                    local ansibleLimit
                    ansibleLimit="master_1,worker_lbs,worker_$((worker_count +1))"
                    local terraformVarOptions
                    terraformVarOptions="-var="master_count=${master_count}" -var="worker_count=$((worker_count+1))""
                    if [[ "${nodeRole}" == "master" ]]; then
                        # Must add master_lb to update loadbalancing configuration
                        ansibleLimit="master_1,master_lb_1,master_$((master_count +1))"
                        terraformVarOptions="-var="master_count=$((master_count+1))" -var="worker_count=${worker_count}""
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
                        if ! ansible-playbook -i "${working_dir}/ansible.inventory.cfg" "${working_dir}/k8s.playbook.yml" --limit "${ansibleLimit}" --tags addNode; then
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
                    private_ip=$(ansible-inventory -i "${working_dir}/ansible.inventory.cfg" --host "${nodeRole}_${instance_count}" | jq .private_ip | tr -d '"')
                    local node_name
                    while [[ -z "${node_name}" ]]; do
                        node_name=$(kubectl_func get node -o wide | grep "${private_ip}" | awk '{ print $1 }')
                        if [[ -n "${node_name}" ]]; then
                            break 1
                        fi
                        
                        # when the node is in inventory but not in kubernetes nodes
                        eval "${working_dir}/$(basename "$0") refresh"
                    done
                    

                    # Kubernetes cordon
                    kubectl_func cordon "${node_name}"
                    # Kubernetes drain
                    if kubectl_func drain "${node_name}" --ignore-daemonsets; then
                        # Kubernetes delete node
                        kubectl_func delete node "${node_name}"
                        # Scale down infrastructure
                        local terraformVarOptions
                        terraformVarOptions="-var="master_count=${master_count}" -var="worker_count=$((worker_count-1))""
                        if [[ "${nodeRole}" == "master" ]]; then
                            terraformVarOptions="-var="master_count=$((master_count-1))" -var="worker_count=${worker_count}""
                        fi
                        local count
                        count=1
                        while true; do
                            if terraform_func apply -auto-approve ${terraformVarOptions}; then
                                if ansible-playbook -i "${working_dir}/ansible.inventory.cfg" "${working_dir}/k8s.playbook.yml" --limit "worker_lbs" --tags deleteNode; then
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
                    rm -f ${working_dir}/tf_k8s*

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
                if ansible-playbook -i "${working_dir}/ansible.inventory.cfg" "${working_dir}/k8s.playbook.yml"; then
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
            actions+=("scale up master")
            actions+=("scale down")
            actions+=("refresh")
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
            eval "${thisScriptPath} ${actionMap[${actionKeyChose}]}"
            return $?
        ;;
    esac
    return 0
}

main "${@}"
