from colorama import Fore
from json import dump, load
from os import path
from shutil import which

CACHE_PATH = 'cache.json'
PACKAGES = {
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
def update_cache(kv):
    try:
        # If the file exists
        if path.exists(CACHE_PATH):
            # Load its content
            with open(CACHE_PATH, 'r') as file:
                data = load(file)
        else:
            # New cache
            data = {}
        
        # Add data to the cache
        data.update(kv)
        
        # Write the updated data back to the file
        with open(CACHE_PATH, 'w') as file:
            dump(data, file, indent=4)
    except Exception as e:
        print(e)

def check_packages():
    # For each package check if it exists and add it to the cache
    installed_packages = []
    for k in PACKAGES.keys():
        path = which(k)
        if path:
            installed_packages.append(k)
    update_cache({'packages': installed_packages})
    print('{}>{} The following packages were found: {}'.format(Fore.BLUE, Fore.RESET, installed_packages))
