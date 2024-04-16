from colorama import init, Fore
from platform import system
from utils import check_packages, update_cache

# Initialize colorama
init()

# Check system
match system():
    case 'Darwin':
         # Update system in cache
        update_cache({'system': 'darwin'})
        print('{}>{} System set to Darwin'.format(Fore.BLUE, Fore.RESET))
        check_packages()
    case 'Linux':
        # Update system in cache
        update_cache({'system': 'linux'})
        print('{}>{} System set to Linux'.format(Fore.BLUE, Fore.RESET))
        check_packages()
    case 'Windows':
        # Update system in cache
        update_cache({'system': 'windows'})
        print('{}>{} System set to Windows'.format(Fore.BLUE, Fore.RESET))
        check_packages()
