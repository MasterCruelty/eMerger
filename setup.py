from colorama import init, Fore
from platform import system
from utils import Utils

if __name__ == '__main__':
    # Initialize colorama
    init()
    print('{}----- SETUP PROCESS -----{}'.format(Fore.GREEN, Fore.RESET))

    # Check system
    utils = Utils()
    match system():
        case 'Darwin':
            # Update system in cache
            utils.update_cache({'system': 'darwin'})
            print('{}>{} System set to Darwin'.format(Fore.BLUE, Fore.RESET))
            # Update packages
            utils.check_packages()
        case 'Linux':
            # Update system in cache
            utils.update_cache({'system': 'linux'})
            print('{}>{} System set to Linux'.format(Fore.BLUE, Fore.RESET))
            # Update packages
            utils.check_packages()
        case 'Windows':
            # Update system in cache
            utils.update_cache({'system': 'windows'})
            print('{}>{} System set to Windows'.format(Fore.BLUE, Fore.RESET))
            # Update packages
            utils.check_packages()
        case _:
            print('{}> THE SYSTEM IS NOT SUPPORTED: ABORTING SETUP{}'.format(Fore.RED, Fore.RESET))
            exit()
