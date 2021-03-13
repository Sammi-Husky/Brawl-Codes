import sys
import io
import re


def find_modules(filepath):
    with open(filepath, 'r') as f:
        loaded = {}
        for line in f:
            if '<<gfModule>>' in line.strip():
                if 'ft_' in line:
                    continue
                m = re.findall('(?:[a-zA-Z]+\:\s*)([\w\.]+)', line.strip())
                if m[4] not in loaded:
                    loaded[m[4]] = m[3]
        return loaded
        
def print_usage():
    print('python3 find.py [dolphin log]')

if len(sys.argv) < 2:
    print_usage()
else:
    modules = find_modules(sys.argv[1])
    print(f'{".text:":<15}{"Filename:":<30}')
    print('----------------------------------------------')
    print('\n'.join([f'{v:<15}{k:<30}' for k,v in modules.items()]))