#!/usr/bin/env bash
#set -e
#set -xv

echo ""
echo "-------- v1.0.1.1 --------"

echo ""
echo "=== Environment variables ==="
echo "INPUT_PROJECT_PATH:      ${INPUT_PROJECT_PATH}"
echo "INPUT_CPPCHECK_OPTIONS:  ${INPUT_CPPCHECK_OPTIONS}"
echo "GITHUB_EVENT_NAME:       ${GITHUB_EVENT_NAME}"
echo ""
echo "=== Print Environment variables ==="
printenv

if [ "${GITHUB_EVENT_NAME}" = "push" ]; then
  echo ""
  echo "=== GitHub Event: Push ==="

  echo ""
  echo "=== Get C/C++ files ==="
  cd "${INPUT_PROJECT_PATH}" || (
    echo "ERROR: The project path (${INPUT_PROJECT_PATH}) not exists."
    ls -lha "${INPUT_PROJECT_PATH}/.."
    exit 1
  )
  # *.c *.h *.cpp *.hpp *.cc *.c++ *.cp *.cxx
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

if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
  echo ""
  echo "=== GitHub Event: Pull request ==="

  if [[ -z ${GITHUB_TOKEN} ]]; then
    echo "ERROR: The GITHUB_TOKEN is required."
    exit 1
  fi

  echo "=== Get pull request files ==="
  FILES_LINK=$(jq -r '.pull_request._links.self.href' "${GITHUB_EVENT_PATH}")/files
  echo "Files = ${FILES_LINK}"

  curl "${FILES_LINK}" > files.json
  FILES_URLS_STRING=$(jq -r '.[].raw_url' files.json)

  readarray -t URLS <<< "${FILES_URLS_STRING}"

  echo "File names: " "${URLS[@]}"

  mkdir -p files
  cd files || (
    echo "ERROR: The files directory is not accesible."
    ls -lha .
    exit 1
  )

  echo "=== Download pull request files ==="
  for URL in "${URLS[@]}"; do
    echo "Downloading ${URL}"
    curl -LOk --remote-name "${URL}"
  done
  ls -lha .

  echo "=== Performing checkup ==="
  for URL in "${URLS[@]}"; do
    FILE_NAME=$(basename "${URL}")
    clang-tidy "${FILE_NAME}" -checks=boost-*,bugprone-*,performance-*,readability-*,portability-*,modernize-*,clang-analyzer-cplusplus-*,clang-analyzer-*,cppcoreguidelines-* >> clang-tidy-report.txt
    clang-format --dry-run -Werror "${FILE_NAME}" || echo "File: ${FILE_NAME} not formatted!" >> clang-format-report.txt
  done

  cppcheck --enable=all --std=c++11 --language=c++ --output-file=cppcheck-report.txt *.c *.h *.cpp *.hpp *.C *.cc *.CPP *.c++ *.cp *.cxx

  echo "CLang Tidy style:"
  clang-tidy --version
  echo "-----------------"
  clang-tidy --dump-config
  echo "-----------------"
  clang-tidy --list-checks
  echo "-----------------"
  clang-tidy --help-list-hidden
  echo "-----------------"
  clang-format --style=llvm -i *.c *.h *.cpp *.hpp *.C *.cc *.CPP *.c++ *.cp *.cxx > clang-format-report-details.txt

  PAYLOAD_TIDY=$(cat clang-tidy-report.txt)
  PAYLOAD_FORMAT=$(cat clang-format-report.txt)
  PAYLOAD_FORMAT_DETAILS=$(cat clang-format-report-details.txt)
  PAYLOAD_CPPCHECK=$(cat cppcheck-report.txt)
  COMMENTS_URL=$(cat "${GITHUB_EVENT_PATH}" | jq -r .pull_request.comments_url)

  echo "=== Display the reports ==="
  echo "${COMMENTS_URL}"
  echo "Clang-tidy errors:"
  echo "${PAYLOAD_TIDY}"
  echo "Clang-format errors:"
  echo "${PAYLOAD_FORMAT}"
  echo "Clang-format details errors:"
  echo "${PAYLOAD_FORMAT_DETAILS}"
  echo "Cppcheck errors:"
  echo "${PAYLOAD_CPPCHECK}"

  echo "=== Generate the output ==="
  if [ "${PAYLOAD_TIDY}" != "" ]; then
    OUTPUT=$'**CLANG-TIDY WARNINGS**:\n'
    OUTPUT+=$'\n```\n'
    OUTPUT+="${PAYLOAD_TIDY}"
    OUTPUT+=$'\n```\n'
  fi

  if [ "${PAYLOAD_FORMAT}" != "" ]; then
    OUTPUT=$'**CLANG-FORMAT WARNINGS**:\n'
    OUTPUT+=$'\n```\n'
    OUTPUT+="${PAYLOAD_FORMAT}"
    OUTPUT+=$'\n```\n'
  fi

  if [ "${PAYLOAD_CPPCHECK}" != "" ]; then
    OUTPUT+=$'\n**CPPCHECK WARNINGS**:\n'
    OUTPUT+=$'\n```\n'
    OUTPUT+="${PAYLOAD_CPPCHECK}"
    OUTPUT+=$'\n```\n'
  fi

  echo "OUTPUT is:"
  echo "${OUTPUT}"

  echo "=== Generate the payload ==="
  PAYLOAD=$(echo '{}' | jq --arg body "${OUTPUT}" '.body = $body')
  echo "PAYLOAD:"
  echo "${PAYLOAD}"

  echo "=== Send the payload to GitHub API ==="
  curl -s -S -H "Authorization: token ${GITHUB_TOKEN}" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "${PAYLOAD}" "${COMMENTS_URL}"
fi
