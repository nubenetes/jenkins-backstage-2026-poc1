#!/usr/bin/env bash
# ==============================================================================
# Bootstrap Script: Deploy Jenkins with JCasC and Pattern B Seed Job
# Repository: github.com/nubenetes/jenkins-backstage-2026-poc1
# File: bin/bootstrap.sh
# ==============================================================================
set -euo pipefail

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="${1:-jenkins-ci}"
RELEASE_NAME="jenkins"
CHART_REPO="https://charts.jenkins.io"
WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}🚀 Bootstrapping Jenkins GitOps Engine (Pattern B) in Namespace: ${NAMESPACE}${NC}"
echo -e "${BLUE}================================================================================${NC}"

# 1. Validate Pre-requisites
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ Error: 'helm' CLI is not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || command -v oc >/dev/null 2>&1 || { echo -e "${YELLOW}⚠️ Warning: Neither 'kubectl' nor 'oc' was found in PATH.${NC}"; }

# 2. Add Jenkins Helm Repo
echo -e "\n${YELLOW}📦 Updating Helm Repositories...${NC}"
helm repo add jenkins "${CHART_REPO}" --force-update || true
helm repo update

# 3. Create Target Namespace
if command -v oc >/dev/null 2>&1; then
    echo -e "${YELLOW}☸️ Ensuring OpenShift project '${NAMESPACE}' exists...${NC}"
    oc get project "${NAMESPACE}" >/dev/null 2>&1 || oc new-project "${NAMESPACE}" || true
elif command -v kubectl >/dev/null 2>&1; then
    echo -e "${YELLOW}☸️ Ensuring Kubernetes namespace '${NAMESPACE}' exists...${NC}"
    kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}" || true
fi

# 4. Deploy or Upgrade Jenkins with Wrapper Values
echo -e "\n${YELLOW}🛠️ Executing Helm Upgrade/Install...${NC}"
helm upgrade --install "${RELEASE_NAME}" jenkins/jenkins \
    --namespace "${NAMESPACE}" \
    --values "${WRAPPER_DIR}/charts/jenkins-wrapper/values.yaml" \
    --wait --timeout 10m

echo -e "\n${GREEN}================================================================================${NC}"
echo -e "${GREEN}✅ Jenkins Controller & JCasC Seed Job Successfully Bootstrapped!${NC}"
echo -e "${GREEN}================================================================================${NC}"
echo -e "Access your Jenkins Instance:"
echo -e "  - Local Port-Forward: ${BLUE}kubectl port-forward svc/jenkins 8080:8080 -n ${NAMESPACE}${NC}"
echo -e "  - Admin User:         ${YELLOW}admin${NC}"
echo -e "  - Admin Password:     ${YELLOW}admin123456 (or check Helm secret)${NC}"
echo -e "  - Seed Job:           ${BLUE}http://localhost:8080/job/Seed_Job_Pattern_B/${NC}"
echo -e "\nTriggering the Seed Job will automatically read 'inventories/*.yaml' and instantiate all microservice pipelines."
