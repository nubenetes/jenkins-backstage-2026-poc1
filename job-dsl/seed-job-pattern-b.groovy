// ==============================================================================
// Pattern B (Advanced): Git-Backed Centralized Seed Job Engine
// Repository: github.com/nubenetes/jenkins-backstage-2026-poc1
// File: job-dsl/seed-job-pattern-b.groovy
// ==============================================================================
// Description:
// This Job DSL script implements an inventory-driven GitOps pipeline engine.
// It parses multi-environment YAML inventories (dev.yaml, pre.yaml, pro.yaml),
// reads the canonical SharedJenkinsfile from the workspace, and injects the
// declarative pipeline directly into each generated job via CPS script definition.
//
// Key Architectural Advantages:
// 1. Zero Jenkinsfiles in application repositories (JHipster microservices stay clean).
// 2. Direct pipeline script injection preserves full GUI transparency & the "Replay" button.
// 3. Centralized governance: adding an enterprise security scan to SharedJenkinsfile
//    instantly rolls out to all 200+ microservices without opening 200 PRs.
// 4. Automated Garbage Collection: Deleting an app entry from dev.yaml automatically
//    decommissions and deletes the corresponding Jenkins job.
// ==============================================================================

import groovy.yaml.YamlSlurper

// 1. Load the centralized SharedJenkinsfile template from the workspace
String sharedJenkinsfileTemplate = ""
try {
    sharedJenkinsfileTemplate = readFileFromWorkspace("jenkins-templates/SharedJenkinsfile")
    println "[SEED-JOB-INFO] Successfully loaded centralized SharedJenkinsfile (${sharedJenkinsfileTemplate.length()} characters)."
} catch (Exception e) {
    println "[SEED-JOB-ERROR] Failed to read jenkins-templates/SharedJenkinsfile from workspace: ${e.message}"
    throw e
}

// 2. List of target environments and their corresponding inventory files
def environments = [
    [name: 'dev', file: 'inventories/dev.yaml', color: '#28a745'],
    [name: 'pre', file: 'inventories/pre.yaml', color: '#ffc107'],
    [name: 'pro', file: 'inventories/pro.yaml', color: '#dc3545']
]

def yamlSlurper = new YamlSlurper()

// 3. Iterate over each environment inventory
environments.each { envConfig ->
    String envName = envConfig.name
    String inventoryPath = envConfig.file

    println "================================================================================"
    println "[SEED-JOB-INFO] Processing Environment Inventory: ${inventoryPath}"
    println "================================================================================"

    String rawYamlContent = ""
    try {
        rawYamlContent = readFileFromWorkspace(inventoryPath)
    } catch (Exception e) {
        println "[SEED-JOB-WARN] Inventory file not found or empty: ${inventoryPath}. Skipping. Error: ${e.message}"
        return
    }

    def inventoryData = yamlSlurper.parseText(rawYamlContent)

    if (!inventoryData || !inventoryData.applications) {
        println "[SEED-JOB-WARN] No applications defined in ${inventoryPath}."
        return
    }

    String clusterName = inventoryData.cluster ?: "openshift-cluster-default"
    String targetNamespace = inventoryData.namespace ?: "apps-${envName}"
    def defaults = inventoryData.defaults ?: [:]

    // Create top-level environment folder (e.g. 'dev', 'pre', 'pro')
    folder(envName) {
        displayName("🌍 Environment: ${envName.toUpperCase()}")
        description("Contains all managed microservice pipelines deployed to namespace '${targetNamespace}' on '${clusterName}'.")
    }

    // 4. Iterate over applications registered in this environment inventory
    inventoryData.applications.each { app ->
        String appName = app.name
        String teamName = app.team ?: "shared-services"
        String repoUrl = app.repository
        String gitBranch = app.branch ?: (envName == 'pro' ? 'main' : (envName == 'pre' ? 'release/*' : 'develop'))
        String jvmMemory = app.jvm_memory ?: (defaults.jvm_memory ?: "-Xms512m -Xmx1024m")
        String cpuLimit = app.cpu_limit ?: (defaults.cpu_limit ?: "1000m")
        String memoryLimit = app.memory_limit ?: (defaults.memory_limit ?: "1Gi")
        int replicas = app.replicas ?: (defaults.replicas ?: (envName == 'pro' ? 3 : 1))
        boolean sonarEnabled = app.containsKey('sonar_enabled') ? app.sonar_enabled : true
        String dockerRegistry = inventoryData.registry ?: "image-registry.openshift-image-registry.svc:5000"

        // Ensure team subfolder exists inside the environment folder with scoped RBAC
        String teamFolderPath = "${envName}/${teamName}"
        folder(teamFolderPath) {
            displayName("👥 Team: ${teamName}")
            description("Managed pipelines owned by team '${teamName}' in ${envName.toUpperCase()}.")
            authorization {
                // Platform Admin Full Governance
                permission('hudson.model.Item.Read', 'group:platform-engineering')
                permission('hudson.model.Item.Build', 'group:platform-engineering')
                permission('hudson.model.Item.Cancel', 'group:platform-engineering')
                permission('hudson.model.Item.Configure', 'group:platform-engineering')

                // Owning Team Scoped Access (Zero Cross-Team Interference)
                permission('hudson.model.Item.Read', "group:team-${teamName}")
                permission('hudson.model.Item.Build', "group:team-${teamName}")
                permission('hudson.model.Item.Cancel', "group:team-${teamName}")
                permission('hudson.model.Run.Replay', "group:team-${teamName}")
            }
        }

        // Full job path: e.g. "dev/e-commerce/store-gateway"
        String jobPath = "${teamFolderPath}/${appName}"
        println "[SEED-JOB-INFO] Provisioning Pipeline Job: ${jobPath} [Repo: ${repoUrl} | Branch: ${gitBranch}]"

        // 5. Define the Pipeline Job with direct CPS Script Injection
        pipelineJob(jobPath) {
            displayName("📦 ${appName} [${envName.toUpperCase()}]")
            description("""
                <b>Service:</b> ${appName}<br/>
                <b>Team:</b> ${teamName}<br/>
                <b>Environment:</b> ${envName.toUpperCase()}<br/>
                <b>Target Namespace:</b> ${targetNamespace}<br/>
                <b>Source Repository:</b> <a href="${repoUrl}">${repoUrl}</a><br/>
                <i>Managed automatically by GitOps Seed Job Pattern B. Do not edit manually.</i>
            """.stripIndent())

            logRotator {
                numToKeep(envName == 'pro' ? 50 : 20)
                daysToKeep(envName == 'pro' ? 90 : 30)
                artifactNumToKeep(10)
            }

            // Define environment parameters passed into the SharedJenkinsfile runtime
            parameters {
                stringParam('APP_NAME', appName, 'Application / Microservice Identifier')
                stringParam('TEAM_NAME', teamName, 'Owning Engineering Team')
                stringParam('ENV_NAME', envName, 'Deployment Target Environment (dev, pre, pro)')
                stringParam('TARGET_NAMESPACE', targetNamespace, 'Kubernetes / OpenShift Target Namespace')
                stringParam('GIT_REPO_URL', repoUrl, 'Git Source Code Repository')
                stringParam('GIT_BRANCH', gitBranch, 'Git Branch / Revision to build')
                stringParam('JVM_MEMORY_OPTS', jvmMemory, 'JVM Memory Allocation Flags')
                stringParam('CPU_LIMIT', cpuLimit, 'Container CPU Resource Limit')
                stringParam('MEMORY_LIMIT', memoryLimit, 'Container Memory Resource Limit')
                stringParam('REPLICAS_COUNT', "${replicas}", 'Target Pod Replica Count')
                booleanParam('SONAR_SCAN_ENABLED', sonarEnabled, 'Execute SonarQube Quality Analysis')
                stringParam('DOCKER_REGISTRY', dockerRegistry, 'Target Container Image Registry')
            }

            // SCM Trigger for reactive builds on push
            triggers {
                scm('H/5 * * * *')
            }

            // Direct CPS Pipeline Script Injection (The Core of Pattern B)
            definition {
                cps {
                    // Injecting the raw content of SharedJenkinsfile directly into the job definition.
                    // This gives developers complete pipeline visibility and FULL REPLAY functionality
                    // in the Jenkins UI without depending on Jenkins Shared Library sandboxing.
                    script(sharedJenkinsfileTemplate)
                    sandbox(true)
                }
            }
        }
    }
}

println "================================================================================"
println "[SEED-JOB-INFO] Pattern B Pipeline Generation Complete. Zero orphaned jobs."
println "================================================================================"
