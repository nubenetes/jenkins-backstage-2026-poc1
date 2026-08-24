#!/usr/bin/env bash
# ==============================================================================
# Simulation Script: Register a New Application in Pattern B Inventories
# Repository: github.com/nubenetes/jenkins-backstage-2026-poc1
# File: bin/register-app.sh
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
APP_NAME=""
TEAM_NAME="e-commerce"
REPO_URL=""
GIT_BRANCH="develop"
TARGET_ENV="dev"
JVM_MEM="-Xms256m -Xmx512m"
CPU_LIMIT="500m"
MEM_LIMIT="1Gi"
REPLICAS=1
SONAR_ENABLED=true

usage() {
    echo -e "Usage: $0 [options]"
    echo -e "Options:"
    echo -e "  -n, --name <name>          Application / Microservice name (Required)"
    echo -e "  -t, --team <team>          Team name (default: 'e-commerce')"
    echo -e "  -r, --repo <url>           Git repository URL (Required)"
    echo -e "  -b, --branch <branch>      Target branch (default: 'develop')"
    echo -e "  -e, --env <environment>    Target environment: dev|pre|pro (default: 'dev')"
    echo -e "      --jvm-memory <opts>    JVM options (default: '-Xms256m -Xmx512m')"
    echo -e "      --cpu <limit>          CPU limit (default: '500m')"
    echo -e "      --memory <limit>       Memory limit (default: '1Gi')"
    echo -e "      --replicas <num>       Replica count (default: 1)"
    echo -e "      --no-sonar             Disable SonarQube scan"
    echo -e "  -h, --help                 Show this help message"
    exit 1
}

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name) APP_NAME="$2"; shift 2 ;;
        -t|--team) TEAM_NAME="$2"; shift 2 ;;
        -r|--repo) REPO_URL="$2"; shift 2 ;;
        -b|--branch) GIT_BRANCH="$2"; shift 2 ;;
        -e|--env|--environment) TARGET_ENV="$2"; shift 2 ;;
        --jvm-memory) JVM_MEM="$2"; shift 2 ;;
        --cpu) CPU_LIMIT="$2"; shift 2 ;;
        --memory) MEM_LIMIT="$2"; shift 2 ;;
        --replicas) REPLICAS="$2"; shift 2 ;;
        --no-sonar) SONAR_ENABLED=false; shift ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
done

if [[ -z "${APP_NAME}" || -z "${REPO_URL}" ]]; then
    echo -e "${RED}❌ Error: Both --name and --repo are required parameters.${NC}"
    usage
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY_FILE="${REPO_ROOT}/inventories/${TARGET_ENV}.yaml"

if [[ ! -f "${INVENTORY_FILE}" ]]; then
    echo -e "${RED}❌ Error: Inventory file not found: ${INVENTORY_FILE}${NC}"
    exit 1
fi

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}📝 Backstage Scaffolder Simulation: Registering [${APP_NAME}] -> ${TARGET_ENV}.yaml${NC}"
echo -e "${BLUE}================================================================================${NC}"

# Check if application already exists in the inventory
if grep -q "name: ${APP_NAME}$" "${INVENTORY_FILE}"; then
    echo -e "${YELLOW}⚠️ Application '${APP_NAME}' is already registered in ${INVENTORY_FILE}.${NC}"
    exit 0
fi

# Append YAML block
cat <<EOF >> "${INVENTORY_FILE}"

  - name: ${APP_NAME}
    team: ${TEAM_NAME}
    repository: "${REPO_URL}"
    branch: "${GIT_BRANCH}"
    jvm_memory: "${JVM_MEM}"
    cpu_limit: "${CPU_LIMIT}"
    memory_limit: "${MEM_LIMIT}"
    replicas: ${REPLICAS}
    sonar_enabled: ${SONAR_ENABLED}
EOF

echo -e "${GREEN}✅ Successfully appended '${APP_NAME}' to ${INVENTORY_FILE}!${NC}"
echo -e "\n${YELLOW}Generated YAML Block:${NC}"
tail -n 11 "${INVENTORY_FILE}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. Commit and push this change: ${YELLOW}git commit -am 'feat(gitops): register ${APP_NAME}' && git push${NC}"
echo -e "2. The Jenkins Seed Job (Seed_Job_Pattern_B) will automatically trigger, inject 'jenkins-templates/SharedJenkinsfile', and generate the pipeline under '${TARGET_ENV}/${TEAM_NAME}/${APP_NAME}'."
