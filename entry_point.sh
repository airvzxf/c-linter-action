#!/usr/bin/env bash

echo ""
echo "=== Environment variables ==="
echo "INPUT_PROJECT_PATH:      ${INPUT_PROJECT_PATH}"
echo "INPUT_CHECK_ALL_FILES:   ${INPUT_CHECK_ALL_FILES}"
echo "GITHUB_EVENT_NAME:       ${GITHUB_EVENT_NAME}"
echo "INPUT_CPPCHECK_OPTIONS:  ${INPUT_CPPCHECK_OPTIONS}"
echo "INPUT_CPPCHECK_OPTIONS:  ${INPUT_INSTALL_PACKAGES}"

if [[ ${INPUT_CHECK_ALL_FILES} == "true" ]]; then
  echo ""
  echo "=== Check all source code files ==="

  echo ""
  echo "=== Get C/C++ files ==="
  cd "${INPUT_PROJECT_PATH}" || (
    echo "ERROR: The project path (${INPUT_PROJECT_PATH}) not exists."
    ls -lha "${INPUT_PROJECT_PATH}/.."
    exit 1
  )
  FILES=$(find ./ -type f -regextype posix-extended -iregex '.*\.(c|h)?(\+\+|c|p|pp|xx)')
  echo "FILES: ${FILES}"
  echo "${FILES}" > c_files.txt
  echo "-----"
  cat c_files.txt

  echo ""
  echo "=== Processing #1 ==="
  while IFS= read -r line; do
    echo "line #1: ${line}"
  done < c_files.txt

  echo ""
  echo "=== Performing checkup ==="
  while IFS= read -r FILE; do
    echo "FILE: ---${FILE}---"
    clang-tidy "${FILE}" -checks=boost-*,bugprone-*,performance-*,readability-*,portability-*,modernize-*,clang-analyzer-cplusplus-*,clang-analyzer-*,cppcoreguidelines-* >> clang-tidy-report.txt
    clang-format --dry-run -Werror "${FILE}" || echo "File: ${FILE} not formatted!" >> clang-format-report.txt
    cppcheck --enable=all --std=c++11 --language=c++ "${FILE}" >> cppcheck-report-individual.txt
  done < c_files.txt
  cppcheck --enable=all --std=c++11 --language=c++ --output-file=cppcheck-report.txt "${INPUT_PROJECT_PATH}"/*.c "${INPUT_PROJECT_PATH}"/*.h "${INPUT_PROJECT_PATH}"/*.cpp "${INPUT_PROJECT_PATH}"/*.hpp "${INPUT_PROJECT_PATH}"/*.C "${INPUT_PROJECT_PATH}"/*.cc "${INPUT_PROJECT_PATH}"/*.CPP "${INPUT_PROJECT_PATH}"/*.c++ "${INPUT_PROJECT_PATH}"/*.cp "${INPUT_PROJECT_PATH}"/*.cxx
  rm -f c_files.txt

  echo ""
  echo "=== Report: Tidy ==="
  ls -lha clang-tidy-report.txt

  echo ""
  echo "=== Report: Format ==="
  cat clang-format-report.txt

  echo ""
  echo "=== Report: CPP Check #1 ==="
  cat cppcheck-report-individual.txt

  echo ""
  echo "=== Report: CPP Check #2 ==="
  cat cppcheck-report.txt
fi

if [[ ${GITHUB_EVENT_NAME} == "push" ]]; then
  echo "TODO: Needs to add the code to scan when the GitHub event is pushed."
  exit 0
fi

if [[ ${GITHUB_EVENT_NAME} == "pull_request" ]]; then
  echo ""
  echo "=== GitHub Event: Pull request ==="

  if [[ -z ${GITHUB_TOKEN} ]]; then
    echo "ERROR: The GITHUB_TOKEN is required."
    exit 1
  fi

  echo ""
  echo "=== Get committed files in JSON format ==="
  GITHUB_FILES_JSON=$(jq -r '.pull_request._links.self.href' "${GITHUB_EVENT_PATH}")/files
  echo "GitHub files in JSON: ${GITHUB_FILES_JSON}"

  echo ""
  echo "=== Get committed files ==="
  curl "${GITHUB_FILES_JSON}" > github_files.json
  FILES_LIST=$(jq -r '.[].filename' github_files.json)
  echo "${FILES_LIST}" > committed_files.txt
  rm -f github_files.json

  echo ""
  echo "=== Performing CLang check up ==="
  C_EXTENSIONS=$(
    echo -n \\.c{,c,p,pp,u,uh,x,xx}"$|" \\.h{,h,p,pp,x,xx}"$|" | sed -E 's/ //g;s/\|$//g'
  )

  while IFS= read -r FILE; do
    echo ""
    echo "FILE: ${FILE}"
    if [[ ! ${FILE,,} =~ ${C_EXTENSIONS} ]]; then
      echo "NOTICE: The file is not matching with the C/C++ files."
      continue
    fi

    echo ""
    echo "CLang Tidy:"
    clang-tidy \
      --format-style=llvm \
      --warnings-as-errors=* \
      --header-filter=.* \
      --checks=* \
      "${FILE}" -- "${FILE}" \
      >> clang-tidy-report.txt

    echo ""
    echo "CLang Format:"
    clang-format \
      --style=LLVM \
      --sort-includes \
      --Werror \
      --dry-run \
      "${FILE}" \
      || echo "File: ${FILE} not formatted!" \
        >> clang-format-report.txt
  done < committed_files.txt

  echo ""
  echo "=== Install optional packages  ==="
  # TODO: Needs to add this parameter in the Action
  INPUT_INSTALL_PACKAGES="libbluetooth-dev"
  apt --assume-yes install "${INPUT_INSTALL_PACKAGES}"

  echo ""
  echo "=== Build the application ==="
  rm -fR build
  cmake \
    -S src \
    -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -G "CodeBlocks - Unix Makefiles"
  cmake --build build -- -j "$(nproc)"

  echo ""
  echo "=== Performing CPP Check check up ==="
  cppcheck \
    --language=c \
    --std=c11 \
    --platform=unix64 \
    --library=boost.cfg \
    --library=cppcheck-lib.cfg \
    --library=cppunit.cfg \
    --library=gnu.cfg \
    --library=libcerror.cfg \
    --library=posix.cfg \
    --library=std.cfg \
    --enable=all \
    --inconclusive \
    --force \
    --max-ctu-depth=1000000 \
    --template="----------\n{file}\nMessage: {message}\n  Check: {severity} -> {id}\n  Stack: {callstack}\n   Line: {line}:{column}\n{code}\n" \
    --template-location="----------\n{file}\nNote: {info}\nLine: {line}:{column}\n{code}\n" \
    --project=build/compile_commands.json \
    2> cppcheck-full-report.txt

  sed --in-place -z "s|${PWD}/||g" cppcheck-full-report.txt

  echo "src/main.c" > committed_files.txt
  echo "src/CMakeLists.txt" >> committed_files.txt
  while IFS= read -r FILE; do
    echo ""
    echo "FILE: ${FILE}"
    if [[ ! ${FILE,,} =~ ${C_EXTENSIONS} ]]; then
      continue
    fi
    echo "NOTICE: Added the reference file '${FILE}' into the report."
    grep -Poz "(?s)----------\n${FILE}.+?(?>\n\n)" cppcheck-full-report.txt >> cppcheck-report.txt
  done < committed_files.txt
  rm -f committed_files.txt

  echo ""
  echo "=== Set payloads per package ==="
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
      echo '📝 `cppcheck --language=c --std=c11 --platform=unix64 --library=boost.cfg --library=cppcheck-lib.cfg --library=cppunit.cfg --library=gnu.cfg --library=libcerror.cfg --library=posix.cfg --library=std.cfg --enable=all --inconclusive --force --max-ctu-depth=1000000 --project=build/compile_commands.json`'
      echo "_**Note**: First you need to build your project with the 'COMPILE_COMMANDS' and set this path to the argument '--project='._"
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
    echo ""
    # shellcheck disable=SC2016
    echo 'The `bot` will comment below the errors and how you can check in your local or fix.'
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
