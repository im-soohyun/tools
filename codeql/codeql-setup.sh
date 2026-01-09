#!/bin/bash

ESC=$'\033'
RESET="${ESC}[0m"; BOLD="${ESC}[1m"; DIM="${ESC}[2m"
RED="${ESC}[31m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; BLUE="${ESC}[34m"; MAGENTA="${ESC}[35m"; CYAN="${ESC}[36m"
CHECK="✅"; WARN="⚠️"; SPARKLE="✨"; BOX="📦"; LINK="🔗"; GEAR="🔧"; INBOX="📥"; BROOM="🧹"

divider() { echo -e "${DIM}────────────────────────────────────────────────────────────────${RESET}"; }
banner() {
  echo -e "${MAGENTA}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${MAGENTA}${BOLD}║                    CodeQL Setup                      ║${RESET}"
  echo -e "${MAGENTA}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  divider
}

step() { echo -e "${CYAN}$1${RESET}"; }
ok() { echo -e "${GREEN}${CHECK}  $1${RESET}"; }
note() { echo -e "${YELLOW}${WARN}  $1${RESET}"; }

banner
step "${BOX}  System update and package installation..."
apt update
apt install git wget unzip -y
ok "System packages installed"

step "${GEAR}  CodeQL install & environment setup..."

mkdir -p /home/codeql
mkdir -p /home/codeql/target-repo
ok "Directories prepared"
cd /home/codeql

step "${LINK}  Cloning CodeQL queries repo..."
git clone https://github.com/github/codeql /home/codeql/codeql-repo
ok "CodeQL repo download complete"

step "${INBOX}  Downloading CodeQL CLI..."
wget https://github.com/github/codeql-cli-binaries/releases/download/v2.23.8/codeql-linux64.zip
unzip codeql-linux64.zip
mv ./codeql ./codeql-cli
rm -rf /home/codeql/codeql-linux64.zip
ok "CodeQL CLI installed"

echo 'export PATH=$PATH:/home/codeql/codeql-cli/' >> ~/.bashrc
step "${LINK}  PATH updated: /home/codeql/codeql-cli/"

ok "CodeQL install & setup complete"
note "Run 'source ~/.bashrc' to apply changes"

step "${BROOM}  Removing selected CodeQL queries (CWE-020*, trest)..."
rm -rf /home/codeql/codeql-repo/python/ql/src/Security/CWE-020*
rm -rf /home/codeql/codeql-repo/javascript/ql/src/Security/CWE-020*
rm -rf /home/codeql/codeql-repo/go/ql/src/Security/CWE-020*
rm -rf /home/codeql/codeql-repo/javascript/ql/src/Security/trest
ok "Selected queries removed"

step "${GEAR}  Granting full permissions to CodeQL directories..."
chmod -R 777 /home/codeql/codeql-repo /home/codeql/codeql-cli
ok "Permissions set: 777 (codeql-repo, codeql-cli)"

divider
echo -e "${SPARKLE}  ${BOLD}All set! Happy hunting with CodeQL.${RESET}"
