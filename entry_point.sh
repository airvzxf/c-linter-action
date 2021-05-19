#!/usr/bin/env bash
set -e

echo "=== Environment variables ==="
echo "INPUT_PROJECT_PATH:     ${INPUT_PROJECT_PATH}"
echo "INPUT_CPPCHECK_OPTIONS: ${INPUT_CPPCHECK_OPTIONS}"
echo ""
echo "=== Current location ==="
pwd
echo ""
echo "=== List this directory ==="
ls -lha .
echo ""
echo "=== Print Environment variables ==="
printenv

echo ""
echo "=== Get C/C++ files ==="
cd "${INPUT_PROJECT_PATH}" || (
  echo "Error: The project path (${INPUT_PROJECT_PATH}) not exists."
  ls -lha "${INPUT_PROJECT_PATH}/.."
  exit 1
)
# *.c *.h *.cpp *.hpp *.cc *.c++ *.cp *.cxx
FILES=$(find ./ -type f -regextype posix-extended -iregex '.*\.(c|h)?(\+\+|c|p|pp|xx)')
echo "FILES: ${FILES}"

echo ""
echo "=== Performing checkup ==="
clang-tidy --version
for FILE in "${FILES[@]}"; do
  echo "FILE: ${FILE}"
  clang-tidy "${FILE}" -checks=boost-*,bugprone-*,performance-*,readability-*,portability-*,modernize-*,clang-analyzer-cplusplus-*,clang-analyzer-*,cppcoreguidelines-* >> clang-tidy-report.txt
  clang-format --dry-run -Werror "${FILE}" || echo "File: $filename not formatted!" >> clang-format-report.txt
done
#cppcheck --enable=all --std=c++11 --language=c++ --output-file=cppcheck-report.txt *.c *.h *.cpp *.hpp *.C *.cc *.CPP *.c++ *.cp *.cxx

echo ""
echo "=== Report: Tidy ==="
cat clang-tidy-report.txt

echo ""
echo "=== Report: Format ==="
cat clang-format-report.txt

echo ""
echo "=== Report: CPP Check ==="
#cat cppcheck-report.txt

exit 123

if [[ -z $GITHUB_TOKEN ]]; then
  echo "ERROR: The GITHUB_TOKEN is required."
  exit 1
fi

# Add validation to check the GITHUB_EVENT_NAME is pull_request
FILES_LINK=$(jq -r '.pull_request._links.self.href' "$GITHUB_EVENT_PATH")/files
echo "Files = $FILES_LINK"

curl $FILES_LINK > files.json
FILES_URLS_STRING=$(jq -r '.[].raw_url' files.json)

readarray -t URLS <<< "$FILES_URLS_STRING"

echo "File names: $URLS"

mkdir files
cd files
for i in "${URLS[@]}"; do
  echo "Downloading $i"
  curl -LOk --remote-name $i
done

echo "Files downloaded!"
echo "Performing checkup:"
clang-tidy --version

# clang-format --style=llvm -i *.c *.h *.cpp *.hpp *.C *.cc *.CPP *.c++ *.cp *.cxx > clang-format-report.txt
for i in "${URLS[@]}"; do
  filename=$(basename $i)
  clang-tidy $filename -checks=boost-*,bugprone-*,performance-*,readability-*,portability-*,modernize-*,clang-analyzer-cplusplus-*,clang-analyzer-*,cppcoreguidelines-* >> clang-tidy-report.txt
  clang-format --dry-run -Werror $filename || echo "File: $filename not formatted!" >> clang-format-report.txt
done

cppcheck --enable=all --std=c++11 --language=c++ --output-file=cppcheck-report.txt *.c *.h *.cpp *.hpp *.C *.cc *.CPP *.c++ *.cp *.cxx

PAYLOAD_TIDY=$(cat clang-tidy-report.txt)
PAYLOAD_FORMAT=$(cat clang-format-report.txt)
PAYLOAD_CPPCHECK=$(cat cppcheck-report.txt)
COMMENTS_URL=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.comments_url)

echo $COMMENTS_URL
echo "Clang-tidy errors:"
echo $PAYLOAD_TIDY
echo "Clang-format errors:"
echo $PAYLOAD_FORMAT
echo "Cppcheck errors:"
echo $PAYLOAD_CPPCHECK

if [ "$PAYLOAD_TIDY" != "" ]; then
  OUTPUT=$'**CLANG-TIDY WARNINGS**:\n'
  OUTPUT+=$'\n```\n'
  OUTPUT+="$PAYLOAD_TIDY"
  OUTPUT+=$'\n```\n'
fi

if [ "$PAYLOAD_FORMAT" != "" ]; then
  OUTPUT=$'**CLANG-FORMAT WARNINGS**:\n'
  OUTPUT+=$'\n```\n'
  OUTPUT+="$PAYLOAD_FORMAT"
  OUTPUT+=$'\n```\n'
fi

if [ "$PAYLOAD_CPPCHECK" != "" ]; then
  OUTPUT+=$'\n**CPPCHECK WARNINGS**:\n'
  OUTPUT+=$'\n```\n'
  OUTPUT+="$PAYLOAD_CPPCHECK"
  OUTPUT+=$'\n```\n'
fi

echo "OUTPUT is: \n $OUTPUT"

PAYLOAD=$(echo '{}' | jq --arg body "$OUTPUT" '.body = $body')

curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "$PAYLOAD" "$COMMENTS_URL"
