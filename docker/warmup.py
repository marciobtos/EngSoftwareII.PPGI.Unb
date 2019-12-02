import subprocess
import re

def main():
	runs =3
	for _ in xrange(runs):
		_runexec("mkdir -p /opt/models/Basic")
		_runexec("java -jar /opt/hyst-1.5/src/Hyst.jar -i /opt/optimizations/io.xml -o /opt/models/Basic/31.py -tool hylaa '-settings settings.print_output=False settings.opt_warm_start_lp=False settings.opt_decompose_lp=False -step 0.200000000'")
		_runexec("/usr/bin/python -u /opt/hyst-1.5/src/hybridpy/hybridpy/tool_hylaa.pyc /opt/models/Basic/31.py -")
		_runexec("rm -f /opt/models/Basic/31.py")
	print("Success.")
def _runexec(command_line,timeout=3600):
	rv={}
	formated_command_line="runexec --walltimelimit {} -- {}".format(timeout,command_line)
	output = subprocess.check_output(formated_command_line,
                                     	shell=True,
                                     	cwd='.',
                                     	stderr=subprocess.STDOUT)
	rv['runtime']=_parse_running_time(output)
	rv['exitcode']=_parse_exit_code(output)
	print("command line: {}".format(formated_command_line))
	print("exitcode: {}".format(rv['exitcode']))
	print("time: {}".format(rv['runtime']))
	return rv
		
def _parse_running_time(output):
	pattern = re.compile(r"walltime= *(\d+\.?\d*)")
	matched=pattern.search(output).group(1)
	return float(matched)
def _parse_exit_code(output):
	pattern = re.compile(r"exitcode= *(\d+)")
	matched=pattern.search(output).group(1)
	return int(matched)
class ExecutionError(BaseException):
	def __init__(self, message, errorcode):
		super(ExecutionError, self).__init__(message)
if __name__ == '__main__':
    main()
