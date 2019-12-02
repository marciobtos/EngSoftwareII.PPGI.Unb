'''Script for running the input oscillator optimization evaluation.'''

import time
import subprocess
import math

# make sure hybridpy is on your PYTHONPATH: hyst/src/hybridpy
import hybridpy.hypy as hypy

def main():
    'main funciton'

    measure()

    plot("opt_comparison.gnuplot")
    plot("tool_comparison.gnuplot")

def measure():
    '''run the measurements'''

    timeout_secs = 15
    num_trials = 10 
    
    tools = []
    labels = []
    tool_params = []
    input_xml = []
    
#    tools.append('flowstar')
#    labels.append('Flowstar')
#    tool_params.append('-orders 1')
#    input_xml.append('io.xml')
        
#    tools.append('spaceex')
#    labels.append('SpaceEx')
#    tool_params.append('-scenario supp -skiptol -flowpipe_tol 0 -output-format TXT')
#    input_xml.append('io.xml')
    
    tools.append('hylaa')
    labels.append('Hylaa')
    tool_params.append('-settings settings.print_output=False')
    input_xml.append('io.xml')

    tools.append('hylaa')
    labels.append('Warm')
    tool_params.append('-settings settings.print_output=False ' +
                       'settings.opt_decompose_lp=False')
    input_xml.append('io.xml')
    
    tools.append('hylaa')
    labels.append('Decomp')
    tool_params.append('-settings settings.print_output=False ' +
                       'settings.opt_warm_start_lp=False')
    input_xml.append('io.xml')

    tools.append('hylaa')
    labels.append('Basic')
    tool_params.append('-settings settings.print_output=False ' +
                       'settings.opt_decompose_lp=False settings.opt_warm_start_lp=False')
    input_xml.append('io.xml')

    tools.append('hylaa')
    labels.append('NoInput')
    tool_params.append('-settings settings.print_output=False')
    input_xml.append('ha.xml')

    assert len(labels) == len(tools)

    start = time.time()

    for i in xrange(len(tools)):
        tool = tools[i]
        label = labels[i]

        with open('out/result_{}.dat'.format(label), 'w') as f:
            step_size = 0.2

            while True:
                timeout = False
                total_secs = 0.0
                measured_secs = []

                for _ in xrange(num_trials):
                    params = "{} -step {:.9f}".format(tool_params[i], step_size)

                    e = hypy.Engine(tool, params)
                    e.set_input(input_xml[i])
                    #e.set_output('out/temp.flowstar')

                    print "Running '{}' with step_size = {:.9f}...".format(label, step_size)
                    #e.set_verbose(True)
                    res = e.run(print_stdout=True, run_tool=True)

                    if res['code'] == hypy.Engine.SUCCESS:
                        runtime = res['tool_time']
                        print "Completed after {:2f} seconds".format(runtime)
                        
                        measured_secs.append(runtime)
                        total_secs += runtime
                    else:
                        raise RuntimeError("Running Tool Failed: {}".format(res['code']))

                measured_secs.sort()
            
                #avg_runtime = (total_secs - measured_secs[0] - measured_secs[-1]) / (num_trials - 2)
                #lower_bound = measured_secs[1]
                #upper_bound = measured_secs[-2]
                
                avg_runtime = total_secs / num_trials
                lower_bound = measured_secs[0]
                upper_bound = measured_secs[-1]
                
                print "Average runtime: {:2f}, range = [{:2f}, {:2f}]".format(avg_runtime, lower_bound, upper_bound)

                max_time = 6.28
                num_steps = int(max_time / step_size)
                f.write('{} {} {} {}\n'.format(num_steps, avg_runtime, lower_bound, upper_bound))
                
                if avg_runtime > timeout_secs:
                    break

                step_size /= 1.3

    dif = time.time() - start
    print "Measurement Completed in {:2f} seconds".format(dif)

def plot(filename):
    'make the plot'

    try:
        exit_code = subprocess.call(["gnuplot", filename])

        if exit_code != 0:
            raise RuntimeError("Gnuplot errored running {}; exit code: {}".format(filename, exit_code))

        print "Ran gnuplot on {} successfully.".format(filename)

    except OSError as e:
        raise RuntimeError("Exception while trying to run gnuplot: {}".format(e))

if __name__ == '__main__':
    main()




