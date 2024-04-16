from colorama import Fore
from json import dump, load
from os import path
from shutil import which

class Utils:
    def __init__(self):
        self.CACHE_PATH = 'cache.json'
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

    # Add value to caches
    def update_cache(self, kv) -> None:
        try:
            # If the file exists
            if path.exists(self.CACHE_PATH):
                # Load its content
                with open(self.CACHE_PATH, 'r') as file:
                    data = load(file)
            else:
                # New cache
                data = {}
            
            # Add data to the cache
            data.update(kv)
            
            # Write the updated data back to the file
            with open(self.CACHE_PATH, 'w') as file:
                dump(data, file, indent=4)
        except Exception as e:
            print(e)

    def check_packages(self) -> None:
        # For each package check if it exists and add it to the cache
        installed_packages = []
        for key, value in self.PACKAGES.items():
            path = which(key)
            if path:
                installed_packages.append(value)
        self.update_cache({'packages': installed_packages})
        print('{}>{} The following packages were found: {}'.format(Fore.BLUE, Fore.RESET, installed_packages))
