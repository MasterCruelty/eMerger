from colorama import Fore
from json import load
from os import path
from src.utils.utils import Utils
from subprocess import PIPE, Popen, STDOUT
import sys

utils = Utils()

try:
    # Read application data
    with open('application.json', 'r') as f:
        data = load(f)

    # Read preferences
    with open('preferences.json', 'r') as f:
        preferences = load(f)
    
    # Print the banner
    if (preferences.get('logo') == True):
        with open('src/utils/banner', 'r') as f:
            banner = f.read()
            print(banner)
    
    # Print the system
    system = data.get('system')
    file_extension = data.get('file_extension')
    global_path = data.get('global_path')
    path_divisor = data.get('path_divisor')
    print('{}>{} System detected: {}'.format(Fore.BLUE, Fore.RESET, system.capitalize()))

    # Use packages
    packages = utils.check_packages(False)
    execution_folder = path.join(global_path, 'src', 'system', system, 'package')
    for pkg in packages:
        # The file to execute
        execution_file = '{}{}{}.{}'.format(execution_folder, path_divisor, pkg, file_extension)
        # Create a process
        if system == 'windows':
            process = Popen(['powershell.exe', execution_file], stdout=PIPE, stderr=PIPE, text=True, shell=False,bufsize=1,universal_newlines=True)
        else:
            process = Popen(['/bin/bash', execution_file], stdout=PIPE, stderr=STDOUT, text=True, shell=False,bufsize=1,universal_newlines=True)
        # Read stdout
        for line in process.stdout:
            print(line.strip())
        # Wait for the process to finish and get the return code
        return_code = process.wait()
except Exception as e:
    print(e)
