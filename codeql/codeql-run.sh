#!/bin/bash

read -p $'\033[32m[+] Enter the GitHub repository URL: \033[0m' github_url

echo -e "\033[32m[+] Select language:\033[0m"
echo -e "    1) python"
echo -e "    2) go"
echo -e "    3) javascript"

read -p $'\033[32m[+] Enter the language number (1-3): \033[0m' lang_choice

case "$lang_choice" in
  1) lan="python" ;;
  2) lan="go" ;;
  3) lan="javascript" ;;
  *) echo -e "\033[31m[-] Invalid selection. Please enter 1, 2, or 3.\033[0m"; exit 1 ;;
esac

repo_name=$(basename -s .git "$github_url")

BASE_DIR="/home/codeql"
TARGET_REPO_DIR="${BASE_DIR}/target-repo/${repo_name}-repo"
DB_DIR="${BASE_DIR}/target-repo/${repo_name}-repo/repo-db"
CODEQL_REPO="${BASE_DIR}/codeql-repo/${lan}/ql/src/Security"
OUTPUT_FILE="${BASE_DIR}/target-repo/${repo_name}-repo/${repo_name}.sarif"

echo -e "\033[36m🔗  Cloning: \033[0m$github_url"
mkdir -p "${BASE_DIR}/target-repo"
git clone "$github_url" "$TARGET_REPO_DIR" || { echo -e "\033[31m❌  Failed to clone repository\033[0m"; exit 1; }

echo -e "\033[36m🗄️  Creating CodeQL database...\033[0m"
NODE_OPTIONS=--max-old-space-size=8192 \
codeql database create "$DB_DIR" \
  --language="$lan" \
  --source-root="$TARGET_REPO_DIR" \
  --threads=2 \
  && echo -e "\033[32m✅  Database created: \033[0m$DB_DIR" \
  || { echo -e "\033[31m❌  Failed to create database\033[0m"; exit 1; }

echo -e "\033[36m🧐  Analyzing with CodeQL...\033[0m"
NODE_OPTIONS=--max-old-space-size=8192 \
codeql database analyze "$DB_DIR" \
  "$CODEQL_REPO" \
  --format=sarifv2.1.0 \
  --output="$OUTPUT_FILE" \
  --ram=4096 \
  --threads=0 \
  --rerun \
  && echo -e "\033[32m✅  Analysis complete. Output: \033[0m$OUTPUT_FILE" \
  || { echo -e "\033[31m❌  Failed to analyze\033[0m"; exit 1; }

echo -e "\033[36m📝  Opening in VS Code...\033[0m"
cd "$TARGET_REPO_DIR" || { echo -e "\033[31m❌  Directory not found: $TARGET_REPO_DIR\033[0m"; exit 1; }
code .

echo -e "\033[32m🎉  CodeQL analysis complete.\033[0m"
