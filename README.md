# C-Linter -> GitHub Action

GitHub action for linting the C and C++ code. Uses clang-tidy, clang-format, and cppcheck.

Example of usage:
```text
name: C-Linter

on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  c-linter:
    name: Analyze C/C++ code
    runs-on: ubuntu-latest

    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v2

      - name: Run C-Linter
        uses: airvzxf/c-linter-action@main
```
