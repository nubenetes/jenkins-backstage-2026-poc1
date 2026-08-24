#!/usr/bin/env bash
# ==============================================================================
# Dry-Run Simulation Script: Job DSL Seed Job Generator (Pattern B)
# Repository: github.com/nubenetes/jenkins-backstage-gitops-patterns
# File: bin/simulate-seed.sh
# ==============================================================================
# Usage: ./bin/simulate-seed.sh [inventories_dir]
# Description:
# Parses multi-environment YAML inventories (dev, pre, pro) and simulates
# the exact Jenkins folder hierarchy, job paths, and bound parameters that
# Job DSL would generate on the live Jenkins Controller.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INVENTORIES_DIR="${1:-${REPO_ROOT}/inventories}"
TEMPLATE_PATH="${REPO_ROOT}/jenkins-templates/SharedJenkinsfile"

echo "================================================================================"
echo "🌱 [SIMULATION] Jenkins Pattern B Job DSL Seed Job Dry-Run Engine"
echo "================================================================================"
echo "📁 Inventories Directory: ${INVENTORIES_DIR}"
echo "📄 Pipeline Template:     ${TEMPLATE_PATH}"

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
    echo "❌ ERROR: SharedJenkinsfile template not found at ${TEMPLATE_PATH}"
    exit 1
fi

TEMPLATE_SIZE=$(wc -c < "${TEMPLATE_PATH}" | tr -d ' ')
echo "✅ Template Loaded:       ${TEMPLATE_SIZE} bytes"
echo "================================================================================"

TOTAL_JOBS=0
TOTAL_FOLDERS=0

python3 - <<PYEOF
import os, sys, yaml

inventories_dir = "${INVENTORIES_DIR}"
environments = ["dev", "pre", "pro"]

total_jobs = 0
total_folders = 0

for env in environments:
    inv_file = os.path.join(inventories_dir, f"{env}.yaml")
    if not os.path.isfile(inv_file):
        print(f"⚠️  [WARN] Inventory file not found: {inv_file}")
        continue

    with open(inv_file, 'r') as f:
        data = yaml.safe_load(f)

    if not data or 'applications' not in data:
        print(f"⚠️  [WARN] No applications in {inv_file}")
        continue

    cluster = data.get('cluster', 'openshift-cluster-default')
    namespace = data.get('namespace', f'apps-{env}')
    defaults = data.get('defaults', {})
    apps = data.get('applications', [])

    print(f"\n🌍 [ENVIRONMENT FOLDER] /{env} (Cluster: {cluster} | Namespace: {namespace})")
    total_folders += 1

    # Track team folders
    teams = sorted(list(set(app.get('team', 'shared-services') for app in apps)))
    for team in teams:
        print(f"   └── 👥 [TEAM FOLDER] /{env}/{team}")
        total_folders += 1

    print("\n   📦 [PROVISIONED PIPELINE JOBS]")
    for app in apps:
        app_name = app.get('name')
        team = app.get('team', 'shared-services')
        repo = app.get('repository')
        branch = app.get('branch', 'main' if env == 'pro' else ('release/*' if env == 'pre' else 'develop'))
        jvm = app.get('jvm_memory', defaults.get('jvm_memory', '-Xms512m -Xmx1024m'))
        cpu = app.get('cpu_limit', defaults.get('cpu_limit', '1000m'))
        ram = app.get('memory_limit', defaults.get('memory_limit', '1Gi'))
        replicas = app.get('replicas', defaults.get('replicas', 3 if env == 'pro' else 1))
        sonar = app.get('sonar_enabled', True)

        job_path = f"{env}/{team}/{app_name}"
        total_jobs += 1

        print(f"      ▶ Pipeline: {job_path}")
        print(f"        • Git Repo:    {repo} (Branch: {branch})")
        print(f"        • Parameters:  JVM='{jvm}', CPU='{cpu}', RAM='{ram}', Replicas={replicas}, Sonar={sonar}")
        print(f"        • Definition:  Direct CPS Injection (readFileFromWorkspace) -> Sandbox: true")
        print(f"        • RBAC:        Bind Role 'team-{team}-dev' -> [Job/Read, Job/Build, Job/Replay]\n")

print("================================================================================")
print(f"🎉 [SUMMARY] Dry-run complete: {total_folders} Folders created, {total_jobs} Microservice Pipelines provisioned.")
print(f"🗑️ [GARBAGE COLLECTION] removedJobAction('DELETE') active -> Zero orphaned jobs.")
print("================================================================================")
PYEOF
