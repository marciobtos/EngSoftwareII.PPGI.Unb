import time
import subprocess
import sys
def main(command_line):
  tool_start_time = time.time()
  
  _run(command_line)
  runtime = time.time() - tool_start_time
  print("command line: {} runtime: {}s".format(command_line, runtime))


def _run(command_line):
  output = subprocess.check_output(command_line,
                                   	shell=True,
                                     	cwd='.',
                                     	stderr=subprocess.STDOUT)
if __name__ == '__main__':
  if len(sys.argv) < 2:
    print "Provide at least one command"
  else: 
    command_line =""
    for i in range(1, len(sys.argv)):	
      command_line=command_line + " "+(sys.argv[i])
    main(command_line)

