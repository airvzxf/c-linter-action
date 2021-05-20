# C-Linter -> GitHub Action

GitHub action for linting the C and C++ code. Uses clang-tidy, clang-format, and cppcheck.

Example of usage:

```text
# File in .github/workflows/c-linter.yml
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

## Tools

### Clang-tidy

Visit the [official web page][clang-tidy-web] for deep and detailed information.

- List all the checks: `clang-tidy --list-checks -checks=*`
- Recommended options: `-warnings-as-errors=* -header-filter=.* -checks=*`
- Complete command: `clang-tidy -warnings-as-errors=* -header-filter=.* -checks=* main.c -- main.c`

[clang-tidy-web]: https://clang.llvm.org/extra/clang-tidy/
