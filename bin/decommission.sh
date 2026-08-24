#!/usr/bin/env bash
# ==============================================================================
# Simulation Script: Decommission an Application from Pattern B Inventories
# Repository: github.com/nubenetes/jenkins-backstage-2026-poc1
# File: bin/decommission.sh
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_NAME=""
TARGET_ENV="dev"

usage() {
    echo -e "Usage: $0 [options]"
    echo -e "Options:"
    echo -e "  -n, --name <name>          Application / Microservice name to decommission (Required)"
    echo -e "  -e, --env <environment>    Target environment: dev|pre|pro|all (default: 'dev')"
    echo -e "  -h, --help                 Show this help message"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name) APP_NAME="$2"; shift 2 ;;
        -e|--env|--environment) TARGET_ENV="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
done

if [[ -z "${APP_NAME}" ]]; then
    echo -e "${RED}❌ Error: --name parameter is required.${NC}"
    usage
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

decommission_env() {
    local env_name="$1"
    local file_path="${REPO_ROOT}/inventories/${env_name}.yaml"

    if [[ ! -f "${file_path}" ]]; then
        echo -e "${YELLOW}⚠️ File ${file_path} not found. Skipping.${NC}"
        return
    fi

    echo -e "${BLUE}🗑️ Removing '${APP_NAME}' from ${file_path}...${NC}"

    # Use Python to safely filter out the microservice from the applications list in YAML
    python3 - <<EOF
import sys

inventory_file = "${file_path}"
app_to_remove = "${APP_NAME}"

with open(inventory_file, 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False

for line in lines:
    if line.strip().startswith("- name:") and app_to_remove in line:
        skip = True
        continue
    elif skip and line.strip().startswith("- name:"):
        skip = False
    elif skip and not line.startswith("  "):
        skip = False

    if not skip:
        new_lines.append(line)

with open(inventory_file, 'w') as f:
    f.writelines(new_lines)

print(f"[OK] Cleaned {inventory_file}")
EOF
}

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}🧹 Decommissioning Microservice: [${APP_NAME}]${NC}"
echo -e "${BLUE}================================================================================${NC}"

if [[ "${TARGET_ENV}" == "all" ]]; then
    decommission_env "dev"
    decommission_env "pre"
    decommission_env "pro"
else
    decommission_env "${TARGET_ENV}"
fi

echo -e "\n${GREEN}✅ Decommissioning metadata update complete!${NC}"
echo -e "\n${BLUE}Automated Garbage Collection in Jenkins:${NC}"
echo -e "1. Push this update to the repository: ${YELLOW}git commit -am 'chore(gitops): decommission ${APP_NAME}' && git push${NC}"
echo -e "2. When 'Seed_Job_Pattern_B' executes, Job DSL detects the missing '${APP_NAME}' entry and triggers ${YELLOW}removedJobAction('DELETE')${NC}."
echo -e "3. The pipeline job, folder (if empty), and associated build history are destroyed automatically with zero orphaned resources."
