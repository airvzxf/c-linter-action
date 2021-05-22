#!/usr/bin/env bash

echo ""
echo "=== Environment variables ==="
echo "INPUT_SCAN_FULL_PROJECT:    ${INPUT_SCAN_FULL_PROJECT}"
echo "INPUT_PROJECT_PATH:         ${INPUT_PROJECT_PATH}"
echo "INPUT_BUILD_TYPE:           ${INPUT_BUILD_TYPE}"
echo "INPUT_C_EXTENSIONS:         ${INPUT_C_EXTENSIONS}"
echo "INPUT_CLANG_TIDY_OPTIONS:   ${INPUT_CLANG_TIDY_OPTIONS}"
echo "INPUT_CLANG_FORMAT_OPTIONS: ${INPUT_CLANG_FORMAT_OPTIONS}"
echo "INPUT_CPPCHECK_OPTIONS:     ${INPUT_CPPCHECK_OPTIONS}"
echo "INPUT_INSTALL_PACKAGES:     ${INPUT_INSTALL_PACKAGES}"
echo "GITHUB_EVENT_NAME:          ${GITHUB_EVENT_NAME}"

if [[ ${GITHUB_EVENT_NAME} == "pull_request" ]]; then
  if [[ -z ${GITHUB_TOKEN} ]]; then
    echo "ERROR: The GITHUB_TOKEN is required for the Pull Request check."
    exit 1
  fi
fi

if [[ ${INPUT_SCAN_FULL_PROJECT} == "true" ]]; then
  echo ""
  echo "=== Check all source code files ==="

  echo ""
  echo "=== Get C/C++ files ==="
  FILES=$(find "${INPUT_PROJECT_PATH}" -type f -regextype posix-extended -iregex '.*\.(c|h)?(\+\+|c|p|pp|xx)')
  echo "FILES: ${FILES}"
  echo "${FILES}" > committed_files.txt
fi

if [[ ${GITHUB_EVENT_NAME} == "push" ]]; then
  echo ""
  echo "=== GitHub Event: Push ==="

  echo ""
  echo "=== Get commits on this push ==="
  COMMITS_ID=$(jq -r '.commits[] | .id' "${GITHUB_EVENT_PATH}")
  echo "COMMITS_ID:"
  echo "${COMMITS_ID}"

  echo ""
  echo "=== Get files per commit ==="
  for COMMIT_ID in ${COMMITS_ID}; do
    echo "COMMIT_ID: ${COMMIT_ID}"
    curl --silent \
      "https://api.github.com/repos/airvzxf/bose-connect-app-linux/commits/${COMMIT_ID}" \
      > commit.json
    jq -r '.files[] | select(.status != "deleted") | .filename' commit.json >> committed_files.txt
    rm -f commit.json
  done
fi

if [[ ${GITHUB_EVENT_NAME} == "pull_request" ]]; then
  echo ""
  echo "=== GitHub Event: Pull request ==="

  echo ""
  echo "=== Get committed files link ==="
  PULL_REQUEST_FILES_LINK=$(jq -r '.pull_request._links.self.href' "${GITHUB_EVENT_PATH}")/files
  echo "Pull request files link: ${PULL_REQUEST_FILES_LINK}"

  echo ""
  echo "=== Get committed files ==="
  curl --silent "${PULL_REQUEST_FILES_LINK}" > github_files.json
  FILES_LIST=$(jq -r '.[].filename' github_files.json)
  echo "${FILES_LIST}" > committed_files.txt
  rm -f github_files.json
fi

if [[ -f committed_files.txt ]]; then
  echo ""
  echo "=== Validate committed files ==="
  echo "NOTICE: Not found any file to process."
  exit 0
fi

echo ""
echo "=== Get unique files ==="
mv committed_files.txt unsorted_files.txt
sort unsorted_files.txt | uniq > unique_files.txt
rm -f unsorted_files.txt

echo ""
echo "=== Get existed files ==="
while IFS= read -r FILE; do
  echo "FILE: ${FILE}"
  if [[ ! -f ${FILE} ]]; then
    echo "NOTICE: The file not exists in this directory."
    continue
  fi
  echo "${FILE}" >> committed_files.txt
done < unique_files.txt
rm -f unique_files.txt

echo ""
echo "=== List the file committed files ==="
ls -lha committed_files.txt

echo ""
echo "=== Display committed files ==="
cat committed_files.txt

echo ""
echo "=== Add source code files to the list ==="
while IFS= read -r FILE; do
  echo "FILE: ${FILE}"
  if [[ ! ${FILE,,} =~ ${INPUT_C_EXTENSIONS} ]]; then
    echo "NOTICE: The file is not matching with the C/C++ files."
    continue
  fi
  echo "${FILE}" >> source_code_files.txt
done < committed_files.txt

echo ""
echo "=== Validate if exists any source code file ==="
if [[ ! -f source_code_files.txt ]]; then
  echo "NOTICE: Not found any source code file to process."
  echo "---> Pattern: ${INPUT_C_EXTENSIONS}."
  exit 0
fi

echo ""
echo "=== Display source code files ==="
cat source_code_files.txt

exit 0

if [[ ${GITHUB_EVENT_NAME} == "pull_request" ]]; then
  echo ""
  echo "=== GitHub Event: Pull request ==="

  if [[ -z ${GITHUB_TOKEN} ]]; then
    echo "ERROR: The GITHUB_TOKEN is required."
    exit 1
  fi

  echo ""
  echo "=== Performing CLang check up ==="
  while IFS= read -r FILE; do
    echo ""
    echo "FILE: ${FILE}"
    if [[ ! ${FILE,,} =~ ${INPUT_C_EXTENSIONS} ]]; then
      echo "NOTICE: The file is not matching with the C/C++ files."
      continue
    fi

    echo ""
    echo "CLang Tidy:"
    eval "clang-tidy ${INPUT_CLANG_TIDY_OPTIONS} ${FILE} -- ${FILE} " \
      ">> clang-tidy-report.txt"

    echo ""
    echo "CLang Format:"
    eval "clang-format ${INPUT_CLANG_FORMAT_OPTIONS} ${FILE} " \
      "|| echo \"File: ${FILE} not formatted!\" >> clang-format-report.txt"
  done < source_code_files.txt

  echo ""
  echo "=== Install optional packages  ==="
  if [[ -n ${INPUT_INSTALL_PACKAGES} ]]; then
    apt --assume-yes install "${INPUT_INSTALL_PACKAGES}"
  fi

  echo ""
  echo "=== Build the application ==="
  rm -fR build
  cmake \
    -S "${INPUT_PROJECT_PATH}" \
    -B build \
    -DCMAKE_BUILD_TYPE="${INPUT_BUILD_TYPE}" \
    -G "CodeBlocks - Unix Makefiles"
  cmake --build build -- -j "$(nproc)"

  echo ""
  echo "=== Performing CPP Check check up ==="
  eval "cppcheck ${INPUT_CPPCHECK_OPTIONS} 2> cppcheck-full-report.txt"

  sed --in-place -z "s|${PWD}/||g" cppcheck-full-report.txt

  while IFS= read -r FILE; do
    echo ""
    echo "FILE: ${FILE}"
    if [[ ! ${FILE,,} =~ ${INPUT_C_EXTENSIONS} ]]; then
      echo "NOTICE: The file is not matching with the C/C++ files."
      continue
    fi
    grep -Poz "(?s)----------\n${FILE}.+?(?>\n\n)" cppcheck-full-report.txt >> cppcheck-report.txt
  done < source_code_files.txt
  rm -f source_code_files.txt

  echo ""
  echo "=== Set payloads per tool ==="
  PAYLOAD_TIDY=$(cat clang-tidy-report.txt)
  PAYLOAD_FORMAT=$(cat clang-format-report.txt)
  PAYLOAD_CPPCHECK=$(cat cppcheck-report.txt)
  IS_REPORTED="false"

  if [[ -n ${PAYLOAD_FORMAT} ]]; then
    {
      echo "**CLANG-FORMAT REPORT**:"
      echo ""
      echo "For more information execute:"
      # shellcheck disable=SC2016
      echo '📝 `clang-format --style=LLVM --sort-includes --Werror --dry-run file.c`'
      echo ""
      echo "If you want to do some automatically fixes, try this:"
      # shellcheck disable=SC2016
      echo '🔧 `clang-format -i --style=LLVM --sort-includes file.c`'
      echo ""
      echo '```text'
      echo "${PAYLOAD_FORMAT}"
      echo '```'
      echo ""
      IS_REPORTED="true"
    } > clang-format-report.txt
  fi

  if [[ -n ${PAYLOAD_CPPCHECK} ]]; then
    {
      echo "**CPP CHECK REPORT**:"
      echo ""
      echo "For more information execute:"
      # shellcheck disable=SC2016
      echo '📝 `cppcheck --language=c --std=c11 --platform=unix64 --library=boost.cfg' \
        ' --library=cppcheck-lib.cfg --library=cppunit.cfg --library=gnu.cfg' \
        ' --library=libcerror.cfg --library=posix.cfg --library=std.cfg --enable=all' \
        ' --inconclusive --force --max-ctu-depth=1000000' \
        ' --project=build/compile_commands.json`'
      echo ""
      # shellcheck disable=SC2016
      echo '_**Note**: First you need to build your project with the `COMPILE_COMMANDS`' \
        ' and set this path to the argument ' \
        '`--project=the_build_folder/compile_commands.json`._'
      echo ""
      echo '```text'
      echo "${PAYLOAD_CPPCHECK}"
      echo '```'
      echo ""
      IS_REPORTED="true"
    } > cppcheck-report.txt
  fi

  echo ""
  echo "=== Generate the output ==="
  if [[ -n ${PAYLOAD_TIDY} ]]; then
    {
      echo "**CLANG-TIDY REPORT**:"
      echo ""
      echo "For more information execute:"
      # shellcheck disable=SC2016
      echo '📝 `clang-tidy --format-style=llvm --warnings-as-errors=* --header-filter=.* --checks=* file.c -- file.c`'
      echo ""
      echo "If you want to do some automatically fixes, try this:"
      # shellcheck disable=SC2016
      echo '🔧 `clang-tidy --fix --fix-errors --format-style=llvm --header-filter=.* --checks=* file.c -- file.c`'
      echo ""
      echo '```text'
      echo "${PAYLOAD_TIDY}"
      echo '```'
      echo ""
      IS_REPORTED="true"
    } > clang-tidy-report.txt
  fi

  if [[ ${IS_REPORTED} != "true" ]]; then
    echo "Finished! Not found any output."
    echo "---> The scan did not get any error or source code."
    exit 0
  fi

  echo ""
  echo "=== Error message: Generate the payload ==="
  {
    echo "😢 Sorry, your code did not pass the quality scanners."
    echo "For more information visit: https://github.com/airvzxf/c-linter-action/#readme"
    echo ""
    # shellcheck disable=SC2016
    echo 'The `bot` will comment below the errors and how you can check or fix they in your local.'
    echo ""
    echo "Thanks! 🦥"
    echo ""
  } >> error_message.txt
  PAYLOAD=$(echo '{}' | jq -n --arg body "$(cat error_message.txt)" '.body = $body')
  rm -f error_message.txt

  echo ""
  echo "=== Error message: Send the payload to GitHub API ==="
  COMMENTS_URL=$(jq < "${GITHUB_EVENT_PATH}" -r .pull_request.comments_url)
  curl -s -S \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    --header "Content-Type: application/vnd.github.VERSION.text+json" \
    --data "${PAYLOAD}" \
    "${COMMENTS_URL}"

  REPORT_FILES="clang-format-report.txt cppcheck-report.txt clang-tidy-report.txt"
  for REPORT_FILE in ${REPORT_FILES}; do
    if [[ ! -f ${REPORT_FILE} ]]; then
      continue
    fi
    echo ""
    echo "=== Report: Generate the payload ==="
    echo "REPORT_FILE: ${REPORT_FILE}"
    ls -lha "${REPORT_FILE}"
    PAYLOAD=$(echo '{}' | jq -n --arg body "$(cat "${REPORT_FILE}")" '.body = $body')

    echo ""
    echo "=== Report: Send the payload to GitHub API ==="
    COMMENTS_URL=$(jq < "${GITHUB_EVENT_PATH}" -r .pull_request.comments_url)
    curl -s -S \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      --header "Content-Type: application/vnd.github.VERSION.text+json" \
      --data "${PAYLOAD}" \
      "${COMMENTS_URL}"
  done
fi
