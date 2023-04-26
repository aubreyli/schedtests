#!/bin/bash
#####################
#hackbench config
#####################
: "${hackbench_job_list:="1 2 4 8"}"
: "${hackbench_iterations:=10}"

#####################
#hackbench parameters
#####################
hackbench_work_type="process threads"
hackbench_ipc_mode="pipe sockets"
hackbench_work_loops=10000
hackbench_data_size=100
hackbench_num_fds=$(($(nproc) / 8))
hackbench_pattern_cmd="grep Time"
hackbench_sleep_time=10
hackbench_log_path=$test_path/results/hackbench

run_hackbench_pre()
{
	hackbench -g 1 --process --pipe -l 1 -s 1 &> /dev/null
	if [ $? -ne 0 ]; then
		echo "[schedtests]: hackbench not found or version not compatible"
		echo "Usage: hackbench [-p|--pipe] [-s|--datasize <bytes>] [-l|--loops <num loops>]"
		echo "                 [-g|--groups <num groups] [-f|--fds <num fds>]"
		echo "                 [-T|--threads] [-P|--process] [--help]"
		exit 1
	fi

	# ${A##* } - remove longest leading, keep only the last word)
	last_job=${hackbench_job_list##* }
	tasks=$((last_job * $hackbench_num_fds))
	org_open_files=`ulimit -n`
	# increase open file number
	ulimit -n $((tasks + $(nproc) + $org_open_files))

	for job in $hackbench_job_list; do
		for wt in $hackbench_work_type; do
			for im in $hackbench_ipc_mode; do
				mkdir -p $hackbench_log_path/$wt-$im/group-$job/$run_name
			done
		done
	done
}

run_hackbench_post()
{
	for job in $hackbench_job_list; do
		for wt in $hackbench_work_type; do
			for im in $hackbench_ipc_mode; do
				log_file=$hackbench_log_path/$wt-$im/group-$job/$run_name/hackbench.log
				cat $log_file | $hackbench_pattern_cmd | awk '{print $2}' > \
					$hackbench_log_path/$wt-$im/group-$job/$run_name.log
			done
		done
	done

}
run_hackbench_single()
{
	local job=$1
	local wt=$2
	local im=$3	
	if [ $im == "pipe" ]; then
		hackbench -g $job --$wt --$im -l $hackbench_work_loops -s $hackbench_data_size -f $hackbench_num_fds
	elif [ $im == "sockets" ]; then
		hackbench -g $job --$wt -l $hackbench_work_loops -s $hackbench_data_size -f $hackbench_num_fds
	else
		echo "hackbench: wrong IPC mode!"
	fi
}

run_hackbench_iterations()
{
	local job=$1
	local wt=$2
	local im=$3	

	for i in $(seq 1 $hackbench_iterations); do
		echo "Group:" $job " - Type:" $wt " - Mode:" $im " - Iterations:" $i
		run_hackbench_single $job $wt $im >> $hackbench_log_path/$wt-$im/group-$job/$run_name/hackbench.log
		sleep 1
	done
}

run_hackbench()
{
	for job in $hackbench_job_list; do
		for wt in $hackbench_work_type; do
			for im in $hackbench_ipc_mode; do
				echo "hackbench: wait 10 seconds for the next case"
				sleep $hackbench_sleep_time
				run_hackbench_iterations $job $wt $im
			done
		done
	done
	echo -e "\nhackbench testing completed"
}

run_hackbench_pre
run_hackbench
run_hackbench_post
