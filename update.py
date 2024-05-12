from colorama import init, Fore
from setup import Setup
from subprocess import PIPE, run


if __name__ == "__main__":
    # Initialize colorama
    init()
    print('{}----- UPDATE PROCESS -----{}'.format(Fore.GREEN, Fore.RESET))

    # Pull from source
    url = 'https://github.com/TheMergers/eMerger.git'
    result = run(['git', 'pull', url], stdout=PIPE, stderr=PIPE)
    if result.returncode == 0:
        print('{}>{} Application successfully updated!\n'.format(Fore.BLUE, Fore.RESET))
    else:
        print('{}> SOMETHING WENT WRONG{}'.format(Fore.RED, Fore.RESET))
        print(result.stderr.decode())
    
    # Recreate application.json
    Setup().run_setup()
