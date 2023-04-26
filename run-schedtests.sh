#!/bin/bash
rela_path=`dirname $0`
test_path=`cd "$rela_path" && pwd`

run_name=`uname -r`
# 25% 50% 75% 100% 200%
min_job=$(($(nproc) / 4))
joblist="$min_job $(($min_job * 2)) $(($min_job * 3)) $(($min_job * 4)) $(($min_job * 8))"
runtime=60
iterations=3

run_hackbench()
{
	hackbench_job_list="1 2 4 8"
	hackbench_iterations=$iterations
	. $test_path/benchmarks/hackbench.sh
}

run_netperf()
{
	netperf_job_list=$joblist
	netperf_run_time=$runtime
	netperf_iterations=$iterations
	. $test_path/benchmarks/netperf.sh
}

run_tbench()
{
	tbench_job_list=$joblist
	tbench_run_time=$runtime
	tbench_iterations=$iterations
	. $test_path/benchmarks/tbench.sh
}

run_schbench()
{
	schbench_job_list="1 2 4 8"
	schbench_run_time=$runtime
	schbench_iterations=$iterations
	. $test_path/benchmarks/schbench.sh
}

[ $# = 0 ] && {
        run_hackbench
        run_netperf
        run_tbench
        run_schbench
        exit
}

benchmark=$1

if [ -n "$2" ]; then
	joblist=$2
fi

case "$benchmark" in
	'hackbench'	) run_hackbench	;;
	'netperf'	) run_netperf	;;
	'tbench'	) run_tbench	;;
	'schbench'	) run_schbench	;;
esac
