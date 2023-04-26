#!/bin/bash
#####################
#schbench config
#####################
: "${schbench_job_list:="1 2 4 8"}"
: "${schbench_iterations:=10}"
: "${schbench_run_time:=100}"

#####################
#schbench parameters
#####################
schbench_work_mode="normal"
schbench_worker_threads=$(($(nproc) / 4))
schbench_old_pattern="99.0000th"
schbench_pattern="99.0th"
schbench_sleep_time=10
schbench_log_path=$test_path/results/schbench

run_schbench_pre()
{
	schbench -m 1 -t 1 -r 1 -s -c &> /dev/null
	if [ $? -ne 0 ]; then
		echo "[schedtests]: schbench not found or version not compatible"
		echo "schbench usage:"
		echo "        -m (--message-threads): number of message threads (def: 2)"
		echo "        -t (--threads): worker threads per message thread (def: 16)"
		echo "        -r (--runtime): How long to run before exiting (seconds, def: 30)"
		echo "        -s (--sleeptime): Message thread latency (usec, def: 10000)"
		echo "        -c (--cputime): How long to think during loop (usec, def: 10000)"
		echo "        -a (--auto): grow thread count until latencies hurt (def: off)"
		echo "        -p (--pipe): transfer size bytes to simulate a pipe test (def: 0)"
		echo "        -R (--rps): requests per second mode (count, def: 0)"
		exit 1
	fi
	for job in $schbench_job_list; do
		for wm in $schbench_work_mode; do
			mkdir -p $schbench_log_path/$wm/mthread-$job/$run_name
		done
	done
}

run_schbench_post()
{
	for job in $schbench_job_list; do
		for wm in $schbench_work_mode; do
			log_file=$schbench_log_path/$wm/mthread-$job/$run_name/schbench.log
			if grep -q $schbench_old_pattern $log_file; then
				schbench_pattern=$schbench_old_pattern
			fi
			cat $log_file | grep $schbench_pattern | awk '{print $2}' > \
				$schbench_log_path/$wm/mthread-$job/$run_name.log
		done
	done
}

run_schbench_single()
{
	local job=$1

	schbench -m $job -t $schbench_worker_threads -r $schbench_run_time -s -c
}

run_schbench_iterations()
{
	local job=$1
	local wm=$2

	for i in $(seq 1 $schbench_iterations); do
		echo "mThread:" $job " - Mode:" $wm " - Iterations:" $i
		run_schbench_single $job &>> $schbench_log_path/$wm/mthread-$job/$run_name/schbench.log
		sleep 1
	done
}

run_schbench()
{
	for job in $schbench_job_list; do
		for wm in $schbench_work_mode; do
			echo "schbench: wait 10 seconds for the next case"
			sleep $schbench_sleep_time
			run_schbench_iterations $job $wm
		done
	done
	echo -e "\nschbench testing completed"
}

run_schbench_pre
run_schbench
run_schbench_post
