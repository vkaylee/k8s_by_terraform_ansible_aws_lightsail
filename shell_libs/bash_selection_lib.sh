#!/usr/bin/env bash
# https://dirask.com/posts/Bash-interactive-menu-example-arrow-up-and-down-selection-jm3YGD
function print_menu()  # selected_item, ...menu_items
{
	local function_arguments=($@)

	local selected_item="$1"
	local menu_items=(${function_arguments[@]:1})
	local menu_size="${#menu_items[@]}"

	for (( i = 0; i < $menu_size; ++i ))
	do
		if [ "$i" = "$selected_item" ]
		then
			echo "-> ${menu_items[i]}"
		else
			echo "   ${menu_items[i]}"
		fi
	done
}

function run_menu()  # selected_item, ...menu_items
{
	local function_arguments=($@)

	local selected_item="$1"
	local menu_items=(${function_arguments[@]:1})
	local menu_size="${#menu_items[@]}"
	local menu_limit=$((menu_size - 1))

	clear
	print_menu "$selected_item" "${menu_items[@]}"
	
	while read -rsn1 input
	do
		case "$input"
		in
			$'\x1B')  # ESC ASCII code (https://dirask.com/posts/ASCII-Table-pJ3Y0j)
				read -rsn1 -t 0.1 input
				if [ "$input" = "[" ]  # occurs before arrow code
				then
					read -rsn1 -t 0.1 input
					case "$input"
					in
						A)  # Up Arrow
							if [ "$selected_item" -ge 1 ]
							then
								selected_item=$((selected_item - 1))
								clear
								print_menu "$selected_item" "${menu_items[@]}"
							fi
							;;
						B)  # Down Arrow
							if [ "$selected_item" -lt "$menu_limit" ]
							then
								selected_item=$((selected_item + 1))
								clear
								print_menu "$selected_item" "${menu_items[@]}"
							fi
							;;
					esac
				fi
				read -rsn5 -t 0.1  # flushing stdin
				;;
			"")  # Enter key
				return "$selected_item"
				;;
		esac
	done
}

function show_menu_item()  # selected_item, ...menu_items
{
	local function_arguments=($@)
	local selected_item="$1"
	local menu_items=(${function_arguments[@]:1})
	echo ${menu_items[$selected_item]}
}

# Usage
# #!/usr/bin/env bash
# fileDir="$(dirname $0)"
# # Load lib for selection feature
# source "$fileDir/shell_libs/bash_selection_lib.sh"

# selected_item=0
# run_menu "$selected_item" tf_k8s_master_1-172.26.13.190-admin@18.141.223.39 tf_k8s_master_2-172.26.28.128-admin@18.143.148.83 tf_k8s_master_lb_1-172.26.5.167-admin@54.179.184.64 tf_k8s_worker_1-172.26.1.12-admin@54.251.179.133
# menu_result="$?"

# echo

# menu_item="$(show_menu_item "$menu_result" tf_k8s_master_1-172.26.13.190-admin@18.141.223.39 tf_k8s_master_2-172.26.28.128-admin@18.143.148.83 tf_k8s_master_lb_1-172.26.5.167-admin@54.179.184.64 tf_k8s_worker_1-172.26.1.12-admin@54.251.179.133)"

# echo "You choose $menu_item"
# user_and_host=$(echo $menu_item | grep -oP "\w+@\d+\.\d+\.\d+\.\d+$")

# echo "Do ssh $user_and_host"
# ssh -i tf_k8s $user_and_host
