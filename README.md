# C-Linter -> GitHub Action

GitHub action for linting the C and C++ code. Uses clang-tidy, clang-format, and cppcheck.

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

Option | Description | Required | Default | Example
---    | ---         | ---      | ---     | ---
project_path | Project Directory. | No | ./ | src/
clang_tidy_options | Options for CLang Tidy. | No | --warnings-as-errors=* --header-filter=.* --checks=* | --checks=-clang-analyzer-cplusplus*
clang_format_options | Options for CLang Format. | No | --style=LLVM --sort-includes | --style=Mozilla
cppcheck_options | Options for CPP Check. | No | --xxx | --yyy

## Tools

### CLang Tidy

Visit the [official web page][clang-tidy-web] for more information.

- Recommended options: `--format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=*`
- Complete
  command: `clang-tidy --format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=* main.c -- main.c`
- List all the checks: `clang-tidy --list-checks --checks=*`
- Auto fix option: `--fix --fix-errors`

### CLang format

Visit the [official web page][clang-format-web] for more information.

- Recommended options: `--dry-run --Werror --style=LLVM`
- Complete command: `clang-format --dry-run --Werror --style=LLVM main.c`
- Auto fix option: `-i`

[clang-tidy-web]: https://clang.llvm.org/extra/clang-tidy/index.html

[clang-format-web]: https://clang.llvm.org/docs/ClangFormat.html
