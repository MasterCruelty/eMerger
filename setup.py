from colorama import init, Fore
from os import getcwd, path, remove
from platform import system
from src.utils.utils import Utils


class Setup():
    def __init__(self):
        init()
        self.utils = Utils()
    
    def run_setup(self) -> None:
        print('{}----- SETUP PROCESS -----{}'.format(Fore.GREEN, Fore.RESET))
        
        # If the application data exists then delete it
        if path.exists(self.utils.APPLICATION_DATA):
            remove(self.utils.APPLICATION_DATA)

        # Initialize preferences
        self.utils.init_preferences()
        
        # Get global path
        cwd = getcwd()
        self.utils.update_data({'global_path': cwd})
        print('{}>{} Working directory set to: {}'.format(Fore.BLUE, Fore.RESET, cwd))

        # Check system
        match system():
            case 'Darwin':
                # Update system in data using MacOS info
                self.utils.update_data({'system': 'darwin'})
                self.utils.update_data({'file_extension': 'sh'})
                self.utils.update_data({'path_divisor': '/'})
                print('{}>{} System set to Darwin'.format(Fore.BLUE, Fore.RESET))
                # Update packages MacOS
                self.utils.check_packages()
            case 'Linux':
                # Update system in data using Linux info
                self.utils.update_data({'system': 'linux'})
                self.utils.update_data({'file_extension': 'sh'})
                self.utils.update_data({'path_divisor': '/'})
                print('{}>{} System set to Linux'.format(Fore.BLUE, Fore.RESET))
                # Update packages Linux
                self.utils.check_packages()
            case 'Windows':
                # Update system in data using Windows info
                self.utils.update_data({'system': 'windows'})
                self.utils.update_data({'file_extension': 'ps1'})
                self.utils.update_data({'path_divisor': '\\'})
                print('{}>{} System set to Windows'.format(Fore.BLUE, Fore.RESET))
                # Update packages Windows
                self.utils.check_packages()
            case _:
                print('{}> THE SYSTEM IS NOT SUPPORTED: ABORTING SETUP{}'.format(Fore.RED, Fore.RESET))
                exit()

if __name__ == '__main__':
    Setup().run_setup()
