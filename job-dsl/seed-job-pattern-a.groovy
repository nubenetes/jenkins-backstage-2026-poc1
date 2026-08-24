// ==============================================================================
// Pattern A: Reactive/Automated Branch Discovery (Organization Folder & Multibranch)
// Repository: github.com/nubenetes/jenkins-backstage-gitops-patterns
// File: job-dsl/seed-job-pattern-a.groovy
// ==============================================================================
// Description:
// This Job DSL script creates an Organization Folder / Multibranch Pipeline scanner.
// In Pattern A, every microservice repository is expected to maintain its own
// local Jenkinsfile. Jenkins periodically scans the Git organization or repo,
// automatically creating pipeline jobs for each discovered branch and PR.
//
// Architectural Evaluation:
// - Pros: Zero centralized inventory maintenance; developers control their own pipeline file.
// - Cons: Severe configuration drift; updates to enterprise steps (e.g. security audits)
//         require updating hundreds of repos; pipeline replay with Shared Libraries is brittle.
// ==============================================================================

// Create top-level folder for Pattern A applications
folder('pattern-a-apps') {
    displayName('📂 Pattern A: Branch Discovery Apps')
    description('Container for Multibranch pipelines provisioned via Organization & Branch scanning.')
}

// 1. GitHub Organization Folder scanning for microservices
organizationFolder('pattern-a-apps/nubenetes-microservices-org') {
    displayName('🏢 NubeNetes Microservices GitHub Organization')
    description('Automatically discovers all repositories and branches containing a Jenkinsfile.')

    organizations {
        github {
            repoOwner('nubenetes')
            apiUri('https://api.github.com')
            credentialsId('github-app-credentials')
            traits {
                // Discover branches
                sourceRegexFilter {
                    regex('^(main|master|develop|feature/.*|release/.*|hotfix/.*)$')
                }
                // Discover pull requests from origin
                gitHubPullRequestDiscovery {
                    strategyId(1) // Merging the pull request with the current target branch revision
                }
                // Discover pull requests from forks (trust level)
                gitHubForkDiscovery {
                    strategyId(1)
                    trust(gitHubTrustPermissions())
                }
                // Exclude branches already matched by PRs to avoid duplicate builds
                gitHubExcludeArchivedRepositories()
            }
        }
    }

    // Pipeline project recognizer: requires a Jenkinsfile in each repository
    projectFactories {
        workflowMultiBranchProjectFactory {
            scriptPath('Jenkinsfile')
        }
    }

    // Orphan item strategy: retain old branches for 7 days, max 10 builds
    orphanedItemStrategy {
        discardOldItems {
            daysToKeep(7)
            numToKeep(10)
        }
    }

    // Periodic organization scan trigger
    triggers {
        periodicFolderTrigger {
            interval('1d')
        }
    }
}

// 2. Standalone Multibranch Pipeline for a specific registered microservice
multibranchPipelineJob('pattern-a-apps/store-gateway-multibranch') {
    displayName('🏪 Store Gateway (Multibranch)')
    description('Reactive multibranch pipeline discovering branches with local Jenkinsfile.')

    branchSources {
        branchSource {
            source {
                github {
                    id('store-gateway-src')
                    repoOwner('nubenetes')
                    repository('sample-jhipster-gateway')
                    credentialsId('github-app-credentials')
                    traits {
                        gitHubBranchDiscovery()
                        gitHubPullRequestDiscovery {
                            strategyId(2) // The current pull request revision
                        }
                    }
                }
            }
            strategy {
                defaultBranchPropertyStrategy {
                    props {
                        // Suppress automatic SCM triggers for specific branches if desired
                    }
                }
            }
        }
    }

    factory {
        workflowBranchProjectFactory {
            scriptPath('Jenkinsfile')
        }
    }

    orphanedItemStrategy {
        discardOldItems {
            numToKeep(15)
            daysToKeep(14)
        }
    }
}
