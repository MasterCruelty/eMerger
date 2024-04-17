from colorama import init, Fore
from os import path, remove
from platform import system
from src.utils.utils import Utils

class Setup():
    def __init__(self):
        init()
        self.utils = Utils()
    
    def run_setup(self) -> None:
        print('{}----- SETUP PROCESS -----{}'.format(Fore.GREEN, Fore.RESET))
        
        # If the application cache exists then delete it
        if path.exists(self.utils.APPLICATION_CACHE):
            remove(self.utils.APPLICATION_CACHE)

        # Initialize preferences
            self.utils.init_preferences()
        # Check system
        match system():
            case 'Darwin':
                # Update system in cache
                self.utils.update_cache({'system': 'darwin'})
                print('{}>{} System set to Darwin'.format(Fore.BLUE, Fore.RESET))
                # Update packages
                self.utils.check_packages()
            case 'Linux':
                # Update system in cache
                self.utils.update_cache({'system': 'linux'})
                print('{}>{} System set to Linux'.format(Fore.BLUE, Fore.RESET))
                # Update packages
                self.utils.check_packages()
            case 'Windows':
                # Update system in cache
                self.utils.update_cache({'system': 'windows'})
                print('{}>{} System set to Windows'.format(Fore.BLUE, Fore.RESET))
                # Update packages
                self.utils.check_packages()
            case _:
                print('{}> THE SYSTEM IS NOT SUPPORTED: ABORTING SETUP{}'.format(Fore.RED, Fore.RESET))
                exit()

if __name__ == '__main__':
    Setup().run_setup()
