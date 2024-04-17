from colorama import Fore
from json import dump, load
from os import path
from shutil import which

class Utils:
    def __init__(self):
        self.APPLICATION_CACHE = 'application.json'
        self.APPLICATION_PREFERENCES = 'preferences.json'
        self.LOG = 'src/utils/log'
        self.PACKAGES = {
            "apt-get": "apt",
            "osascript": "arm",
            "choco": "choco",
            "emerge": "emerge",
            "flatpak": "flatpak",
            "nixos-rebuild": "nixos",
            "nuget": "nuget",
            "scoop": "scoop",
            "pacman": "pacman",
            "pkg": "pkg",
            "rpm": "rpm",
            "snap": "snap",
            "yay": "yay",
            "zypper": "zypper"
        }
    
    # Check application cache for installed packages
    def check_packages(self) -> None:
        # For each package check if it exists and add it to the cache
        installed_packages = []
        for key, value in self.PACKAGES.items():
            path = which(key)
            if path:
                installed_packages.append(value)
        self.update_cache({'packages': installed_packages})
        print('{}>{} The following packages were found: {}'.format(Fore.BLUE, Fore.RESET, installed_packages))
    
    # Initialize application preferences
    def init_preferences(self) -> None:
        # Do nothing if preferences are already set
        if not path.exists(self.APPLICATION_PREFERENCES):
            with open(self.APPLICATION_PREFERENCES, 'w') as f:
                dump({
                    "logo": True,
                }, f, indent=4)

    # Add value to caches
    def update_cache(self, kv) -> None:
        try:
            # If the file exists
            if path.exists(self.APPLICATION_CACHE):
                # Load its content
                with open(self.APPLICATION_CACHE, 'r') as f:
                    data = load(f)
            else:
                # New cache
                data = {}
            
            # Add data to the cache
            data.update(kv)
            
            # Write the updated data back to the file
            with open(self.APPLICATION_CACHE, 'w') as f:
                dump(data, f, indent=4)
            self.update_log({"SUCCESS": "UPDATE CACHE -> ADD {}".format(kv)})
        except Exception as e:
            self.update_log({"ERROR": "UPDATE CACHE -> {}".format(e)})

    def update_log(self, kv) -> None:
        try:
            # Open the log file in append mode
            with open(self.LOG, 'a') as file:
                # Iterate over each key-value pair in kv
                for key, value in kv.items():
                    # Write the key-value pair as a new line in the log file
                    file.write('{}: {}\n'.format(key, value))
        except Exception as e:
            print('{}> SOMETHING WENT WRONG{}'.format(Fore.RED, Fore.RESET))
            print('CORRUPTED FOLDER -> UPDATE LOG\n{}'.format(e))
