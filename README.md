# C-Linter -> GitHub Action

GitHub action for linting the C and C++ code. Uses clang-tidy, clang-format, and cppcheck.

Review the [to-do's list][todo-reference] for more information.

## Usage Example

Add this code in `.github/workflows/c-linter.yml`.

```text
# File in '.github/workflows/c-linter.yml'
name: C-Linter

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  c-linter:
    name: Analyze C/C++ source code
    runs-on: ubuntu-latest

    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Run C-Linter
        uses: airvzxf/c-linter-action@main
```

## Settings

Option | Description | Required | Type | Default | Example
---    | ---         | ---      | ---  | ---     | ---
scan_full_project | Scan full project. [Reference](#scan_full_project). | No | String | false | true
project_path | Source code directory. [Reference](#project_path). | No | String | . | src
build_type | Build type. [Reference](#build_type). | No | String | Release | Debug
c_extensions | File extensions for C/C++. | No | String | [Reference](#c_extensions) | \\.c$&#x7c;\\.h$&#x7c;\\.zpp$
clang_tidy_options | Options for CLang Tidy. | No | String | [Reference](#clang_tidy_options) | --checks=*
clang_format_options | Options for CLang Format. | No | String | [Reference](#clang_format_options) | --style=Mozilla
cppcheck_options | Options for CPP Check. | No | String | [Reference](#cppcheck_options) | --enable=style
install_packages | Install extra package. [Reference](#install_packages). | No | String |  | libmemcached

### Settings review

#### scan_full_project

---

It usually checks the quality code from the committed files, if you want to scan and provide report for all the project,
please set this option to `true`.

#### project_path

---

The directory which contain the C/C++ source code and CMake files.

Example of the execution of this setting:

```bash
cmake \
    -S "${project_path}" \
    -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -G "CodeBlocks - Unix Makefiles"
```

#### build_type

---

CMake build types:

- Release
- RelWithDebInfo
- MinSizeRel
- Default
- Debug

Example of the execution of this setting:

```bash
cmake \
    -S . \
    -B build \
    -DCMAKE_BUILD_TYPE="${build_type}" \
    -G "CodeBlocks - Unix Makefiles"
```

#### c_extensions

---

Pattern to match the file extension of C/C++ source code. The rule is that needs to have the dot (.) and then the
extension, it follows the pipeline (|) without spaces after the next extension. Every extension should be in lower case,
since the filter convert the file name in lowercase.

- Default. It is a `bash` regular expression which start with dot and finish with dollar sign, it is indicating match
  only if the end of the string finish on `.xxx`.
    - `\.c$|\.cc$|\.cp$|\.cpp$|\.cu$|\.cuh$|\.cx$|\.cxx$|\.h$|\.hh$|\.hp$|\.hpp$|\.hx$|\.hxx$`
- Unreal examples: `\.doc$|\.zip$|\.py$`

Example of the execution of this setting:

```bash
  while IFS= read -r file; do
    if [[ ! ${file,,} =~ ${c_extensions} ]]; then
      #  The file 'src/bye.txt' not match with the extension then it continue with the next file.
      continue
    fi
    #  The file 'src/library/hello.c' match with the extension then performs an action.
  done < file_list.txt
```

#### clang_tidy_options

---

Set options to the CLang Tidy command. See the [tool reference](#clang-tidy) for it.

The default values are `--format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=*`.

Note: If the project directory contains the `.clang-tidy` file, it will take precedence over any optional parameter that
is specified. Means this options will not take effects.

Example of the execution of this setting:

```bash
eval "clang-tidy ${clang_tidy_options} fie.c -- file.c >> clang-tidy-report.txt"
```

#### clang_format_options

---

Set options to the CLang Format command. See the [tool reference](#clang-format) for it.

The default values are `--style=LLVM --sort-includes --Werror --dry-run`.

Note: If the project directory contains the `.clang-format` file, looks like it does not take this in count, the
parameters still needed.

Example of the execution of this setting:

```bash
eval "clang-format ${clang_format_options} file.c || echo 'Not formatted!' >> clang-format-report.txt"
```

#### cppcheck_options

---

Set options to the CPP Check command. See the [tool reference](#cpp-check) for it.

The default values are:

- `--language=c`
- `--std=c11`
- `--platform=unix64`
- `--library=boost.cfg`
- `--library=cppcheck-lib.cfg`
- `--library=cppunit.cfg`
- `--library=gnu.cfg`
- `--library=libcerror.cfg`
- `--library=posix.cfg`
- `--library=std.cfg`
- `--enable=all`
- `--inconclusive`
- `--force`
- `--max-ctu-depth=1000000`
- `--template="----------\n{file}\nMessage: {message}\n  Check: {severity} -> {id}\n  Stack: {callstack}\n   Line: {line}:{column}\n{code}\n"`
- `--template-location="----------\n{file}\nNote: {info}\nLine: {line}:{column}\n{code}\n"`
- `--project=build/compile_commands.json`

Example of the execution of this setting:

```bash
eval "cppcheck ${cppcheck_options} 2> cppcheck-full-report.txt"
```

#### install_packages

---

Install extra package to compile your code inside this action. In case that this option is not specified it will not
install any extra package. To install more than one package separate by spaces ( ).

- Example: `cmake python boost jq clang avir`

Example of the execution of this setting:

```bash
  if [[ -n ${install_packages} ]]; then
    apt --assume-yes install "${install_packages}"
  fi
```

## Tools

### CLang Tidy

Visit the [official web page][clang-tidy-web] for more information.

- Recommended options: `--format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=*`
- Complete command:
  `clang-tidy --format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=* main.c -- main.c`
- List all the checks: `clang-tidy --list-checks --checks=*`
- Auto fix option: `--fix --fix-errors`

### CLang Format

Visit the [official web page][clang-format-web] for more information.

- Recommended options: `--dry-run --Werror --style=LLVM`
- Complete command: `clang-format --dry-run --Werror --style=LLVM main.c`
- Auto fix option: `-i`

### CPP Check

Visit the [official web page][cppcheck-web] for more information.

```bash
cppcheck \
  --language=c \
  --std=c11 \
  --platform=unix64 \
  --suppress=missingIncludeSystem \
  --enable=all \
  --inconclusive \
  --force \
  --max-ctu-depth=1000000 \
  --library=boost.cfg \
  --library=cppcheck-lib.cfg \
  --library=cppunit.cfg \
  --library=gnu.cfg \
  --library=libcerror.cfg \
  --library=posix.cfg \
  --library=std.cfg \
  --template="----------\n{file}:{line}\nMessage: {message}\n  Check: CWE-{cwe} [{severity} -> {id}]\n  Stack: {callstack}\n   Line: {line}:{column}\n{code}\n" \
  --template-location="----------\n{file}:{line}\nNote: {info}\nLine: {line}:{column}\n{code}\n" \
  --project=build/compile_commands.json \
  2> cppcheck-full-report.txt
```

Options:

- `--language` - Forces to check all files as the given language.
    - c
    - c++
- `--std` - Set standard.
    - c89
    - c99
    - c11
    - c++03
    - c++11
    - c++14
    - c++17
    - c++20
- `--platform` - Specifies platform specific types and sizes.
    - unix32
    - unix64
    - win32A
    - win32W
    - win64
    - avr8
    - native
    - unspecified
- `--library` - Load file <cfg> that contains information about types and functions. With such information Cppcheck
  understands your code better and therefore you get better results.
- `--enable` - Enable additional checks.
    - all
    - warning
    - style
    - performance
    - portability
    - information
    - unusedFunction
    - missingInclude
- `--inconclusive` - Allow that Cppcheck reports even though the analysis is inconclusive.
- `--force` - Force checking of all configurations in files.
- `--max-ctu-depth` - Max depth in whole program analysis. The default value is 2. A larger value will mean more errors
  can be found but also means the analysis will be slower.
- `--template` - Format the error messages.
- `--template-location` - Format error message location.
- `--project` - Run Cppcheck on project. The <file> can be a Visual Studio Solution (*.sln), Visual Studio Project (*
  .vcxproj), compile database (compile_commands.json), or Borland C++ Builder 6 (*.bpr). The files to analyse, include
  paths, defines, platform and un-defines in the specified file will be used.
- `2> cppcheck-full-report.txt` - Save the errors in a text file.

[clang-tidy-web]: https://clang.llvm.org/extra/clang-tidy/index.html

[clang-format-web]: https://clang.llvm.org/docs/ClangFormat.html

[cppcheck-web]: https://sourceforge.net/p/cppcheck/wiki/Home/

[todo-reference]: ./TODO.md
