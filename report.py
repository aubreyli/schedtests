#!/usr/bin/python3
import os
import sys
import getopt
import numpy as np
import pandas as pd

#global benchmark_list
bmk_list = [
    {"name":"hackbench","metrics":"Time",    "better":"-"},
    {"name":"netperf",  "metrics":"Trans/s", "better":"+"},
    {"name":"tbench",   "metrics":"Tput/s",  "better":"+"},
    {"name":"schbench", "metrics":"Lat_99th","better":"-"},
]

class benchmark:
    curr_path = os.getcwd()

    def __init__(self, bmk):

        # the relative log path is ./results
        self.log_path = os.path.join(benchmark.curr_path, "results/" + bmk['name'])

        # metrics extracted as the first column in the log file by bash script
        self.metrics_pos = 0

        self.metrics_str = bmk['metrics']
        self.better = bmk['better']

        # benchmark core table
        self.table = pd.DataFrame(columns =
                        ['case', 'load', 'b_avg', 'b_std', 'c_avg', 'c_std'])

    def _log_parse(self, logfile):

        metrics = []

        fd = open(logfile, 'r')

        for line in fd.readlines():
            items = line.strip().split()
            metrics.append(float(items[self.metrics_pos]))

        fd.close()

        avg = round(np.mean(metrics), 4)
        std = round(100 * np.std(metrics) / avg, 2)

        return avg, std

    def _log_process(self, baseline, compare):
        # The log topology is 4-level structure
        # ./results
        #    |---benchmark                (netperf)
        #        |---case                 (TCP_RR)
        #            |---load             (thread_96)
        #                |---baseline.log (5.10.13-stable.log)
        #                |---compare.log  (5.10.13-icmv8.log)

        for case in os.listdir(self.log_path):
            case_path = os.path.join(self.log_path,case)
            for load in os.listdir(case_path):
                load_path = os.path.join(case_path, load)

                b_avg = 0.0
                b_std = 0.0
                c_avg = 0.0
                c_std = 0.0

                for log in os.listdir(load_path):
                    log_file = os.path.join(load_path, log)
                    # now in the log file directory, ignore baseline
                    # or compare folder
                    if os.path.isdir(log_file):
                        continue
                    avg, std = self._log_parse(log_file)

                    if baseline in log:
                          b_avg = avg
                          b_std = std

                    if compare and compare in log:
                          c_avg = avg
                          c_std = std

                #sanity check
                if b_avg == 0:
                    print("{} log does not exist".format(baseline))
                    sys.exit(1)

                if compare and c_avg == 0:
                    print("{} log does not exist".format(compare))
                    sys.exit(1)

                self.table = self.table.append({
                                'case':case, 'load':load,
                                'b_avg':b_avg, 'b_std':b_std,
                                'c_avg':c_avg, 'c_std':c_std},
                                ignore_index=True)

        # sort the table by case column first, then load column
        #
        # netperf
        # ===========
        # case            	load    	     Trans/s	    std%
        # TCP_RR          	thread-96	    74601.39	(  5.14)
        # TCP_RR          	thread-192	    14550.99	(  6.48)
        # TCP_RR          	thread-384	    45175.21	( 15.35)
        # UDP_RR          	thread-96	    74784.91	(  8.99)
        # UDP_RR          	thread-192	    15524.48	( 26.66)
        # UDP_RR          	thread-384	    23963.53	( 27.27)
        self.table['sort'] = self.table['load'].str.extract(
                                '(\d+)', expand = False).astype(int)
        self.table.sort_values(by=['case', 'sort'],
                                inplace = True, ascending= True)
        self.table = self.table.drop('sort', axis = 1).reset_index(drop = True)

    def _baseline_report(self, baseline):
        # print table header
        print('{0:16s}\t{1:8s}\t{2:>12s}\t{3:>8s}' \
            .format('case','load',self.metrics_str,'std%'))

        # print table body
        for i in range(len(self.table)):
            print('{0:16s}\t{1:8s}\t{2:12.2f}\t({3:6.2f})' \
                .format(self.table['case'][i], self.table['load'][i],
                self.table['b_avg'][i], self.table['b_std'][i]))

    def _compare_report(self, baseline, compare):
        #print table header
        print('{0:16s}\t{1:8s}\t{2}({3})\t{4}({5:>5s})' \
            .format('case','load','baseline','std%','compare%','std%'))

        #print table body
        for i in range(len(self.table)):
            change = self.table['c_avg'][i]/self.table['b_avg'][i]
            if self.better == '-':
                change_pct = round((1 - change) * 100.0, 2)
            else:
                change_pct = round((change - 1) * 100.0, 2)

            print('{0:16s}\t{1:8s}\t{2:5.2f} ({3:6.2f})\t{4:>+6.2f}' \
                    ' ({5:6.2f})'.format(self.table['case'][i],
                    self.table['load'][i], 1.0, self.table['b_std'][i],
                    change_pct, self.table['c_std'][i]))

    def report(self, bmk, baseline, compare):
	#output benchmark name
        print("\n{}".format(bmk['name']))
        print("{}".format("=" * len(bmk['name'])))

        self._log_process(baseline, compare)

        if not compare:
            self._baseline_report(baseline)
        else:
            self._compare_report(baseline, compare)

def usage():
    print("./report.py [-t testname] -b baseline [-c compare]")
    print("\t-t (--testname) test case name")
    print("\t-b (--baseline) baseline run name")
    print("\t-c (--compare) compare run name")

if __name__ == "__main__":

    try:
        opts, args = getopt.getopt(sys.argv[1:], '-h-t:-b:-c:',
                        ['help','testname=','baseline=','compare='])
    except getopt.GetoptError:
        usage()
        # 128 - invalid argument to exit
        sys.exit(128)

    testname = ""
    baseline = ""
    compare = ""

    for opt_name, opt_value in opts:
        if opt_name in ('-h', '--help'):
            usage()
            sys.exit()
        if opt_name in ('-t', '--testname'):
            testname = opt_value
        if opt_name in ('-b', '--baseline'):
            baseline = opt_value
        if opt_name in ('-c', '--compare'):
            compare = opt_value

    # baseline is a must
    if not baseline:
        usage()
        # catchall for general errors
        sys.exit(1)

    for i in range(len(bmk_list)):
        bmk = bmk_list[i]

        if testname and testname not in bmk['name']:
            continue

        task = benchmark(bmk)
        task.report(bmk, baseline, compare)
