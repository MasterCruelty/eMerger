from json import load

try:
    # Read preferences
    with open('preferences.json', 'r') as f:
        preferences = load(f)
    
    # Print the banner
    if (preferences.get('logo') == True):
        with open('src/utils/banner', 'r') as f:
            banner = f.read()
            print(banner)
except Exception as e:
    print(e)
