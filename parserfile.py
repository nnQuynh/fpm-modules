from pathlib import Path
import re

# print(Path.cwd())
# print(Path.home())
# print(f"You can find me here: {Path(__file__).parent}!")








def parse_file(filepath, print_level = 5):
  data_dict = {'file':  filepath.name}
  
  subroutine_pattern=re.compile(r'\s*(recursive|pure|elemental)?\s*(recursive|pure|elemental)?\s+(SUBROUTINE)\s+\S+\(.*',re.IGNORECASE)
  function_pattern=re.compile(r'\s*(recursive|pure|elemental|double precision|logical|integer)?\s*(recursive|pure|elemental|double precision|logical|integer)?\s+(FUNCTION)\s+\S+\(.*',re.IGNORECASE)
  module_pattern=re.compile(r'\s*(MODULE)\s+(\w+)\n',re.IGNORECASE)
  call_pattern=re.compile(r'\s*(call)\s*\S+',re.IGNORECASE)
  end_pattern=re.compile(r'\s+(end)\s*(subroutine|function)?\s*\n',re.IGNORECASE)
  
  
  with open(filepath, 'r') as file:
    leading_space = "    "
    level = 1
    print(f'\n{leading_space*level}- File: {filepath.name}') if level <= print_level else None

    for line in file:
      if (re.fullmatch(module_pattern, line)):
        # print(f'level: {level}')
        level += 1
        # print(line)
        line_split = re.split(r'[;,:\s(]+', line.strip().lower())
        index = line_split.index('module')
        module_name = line_split[index+1]
        print(f'{leading_space*level}+ module: {module_name} - level:{level}') if level <= print_level else None
        continue
      
      if (re.match(subroutine_pattern, line)):
        # print(f'level: {level}')
        level += 1
        # print(line)
        line_split = re.split(r'[;,:\s(]+', line.strip().lower())
        index = line_split.index('subroutine')
        subroutine_name = line_split[index+1]
        print(f'{leading_space*level}. sub:  {subroutine_name} - level:{level}') if level <= print_level else None
        continue
      
      if (re.match(function_pattern, line)):
        # print(f'level: {level}')
        level = level + 1
        # print(line)
        line_split = re.split(r'[;,:\s(]+', line.strip().lower())
        index = line_split.index('function')
        function_name = line_split[index+1]
        print(f'{leading_space*level}. func: {function_name} - level:{level}') if level <= print_level else None
        continue
      
      if (re.fullmatch(call_pattern, line.strip())):
        # print(line)
        # print(f'level call_pattern: {level}')
        line_split = re.split(r'[;,:\s(]+', line.strip().lower())
        index = line_split.index('call')
        call_subroutine_name = line_split[index+1]
        print(f'{leading_space*level}     call: {call_subroutine_name}') if level <= print_level else None
        continue
      
      if (re.match(end_pattern, line)):
        # print(line)
        level -= 1
        # line_split = re.split(r'[\s(]+', line.strip().lower())
        # # print(line_split)
        # index = line_split.index('call')
        # call_subroutine_name = line_split[index+1]
        # print(f'{leading_space*level}. call: {call_subroutine_name}') if level <= print_level else None
        continue

def parse_multi_file(filepathlist, print_level = 5):
  for filepath in filepathlist:
    parse_file(filepath, print_level)
    
def fortran_file_in_directory(directorypath, extensions = [".f", ".F", ".f90", ".F90"] ):
  matching_files = []
  for ext in extensions:
      matching_files.extend(directorypath.glob(f"*{ext}"))
  return matching_files

    
# filepath = Path.cwd().joinpath("src", "utilities.f90")   
# filepath = Path.cwd().joinpath("src", "packages.f90")              
# parse_file(filepath, print_level = 5)

directory_path = Path.cwd().joinpath("src")
fortran_files = fortran_file_in_directory(directory_path)
parse_multi_file(fortran_files,5)
