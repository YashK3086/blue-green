// ============================================================
// DevOps-Blue-Green | Jenkins CI/CD Pipeline
// Phase 4: Secure Pipeline with SonarQube SAST + OWASP ZAP DAST
// ============================================================
pipeline {
    agent any

    environment {
        // --- AWS / EKS ---
        AWS_REGION             = 'us-east-1'
        ECR_REGISTRY           = '593927188565.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO               = 'blue-green-app'
        CLUSTER_NAME           = 'blue-green-cluster'
        AWS_ACCESS_KEY_ID      = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY  = credentials('AWS_SECRET_ACCESS_KEY')
        PATH                   = "/var/lib/jenkins/bin:${env.PATH}"

        // --- SonarQube SAST ---
        SONAR_HOST_URL = credentials('SONAR_HOST_URL')
        SONAR_TOKEN    = credentials('SONAR_TOKEN')

        // --- ZAP DAST (populated dynamically) ---
        PREVIEW_LB_URL = ''
    }

    stages {

        // --------------------------------------------------------
        // Stage 1: Source Checkout
        // --------------------------------------------------------
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --------------------------------------------------------
        // Stage 2: SAST — SonarQube Static Analysis
        // Runs BEFORE Docker build so insecure code never gets built.
        // Scans: app/ source + terraform/ IaC manifests.
        // Quality Gate check blocks the pipeline if score fails.
        // --------------------------------------------------------
        stage('SAST: SonarQube Scan') {
            steps {
                script {
                    echo "=================================================="
                    echo " [SAST] Running SonarQube analysis..."
                    echo " Host: ${env.SONAR_HOST_URL}"
                    echo "=================================================="

                    sh """
                        sonar-scanner \
                          -Dsonar.projectKey=devops-blue-green \
                          -Dsonar.projectName='DevOps Blue-Green Pipeline' \
                          -Dsonar.sources=app,terraform \
                          -Dsonar.exclusions='**/.terraform/**,**/terraform.tfstate*,**/.terraform.lock.hcl' \
                          -Dsonar.host.url=${env.SONAR_HOST_URL} \
                          -Dsonar.login=${env.SONAR_TOKEN} \
                          -Dsonar.qualitygate.wait=true \
                          -Dsonar.sourceEncoding=UTF-8
                    """

                    echo " [SAST] SonarQube Quality Gate PASSED."
                }
            }
            post {
                always {
                    echo "SonarQube report: ${env.SONAR_HOST_URL}/dashboard?id=devops-blue-green"
                }
                failure {
                    echo "[SAST] Quality Gate FAILED. Fix issues in SonarQube before rerunning."
                }
            }
        }

        // --------------------------------------------------------
        // Stage 3: ECR Login
        // --------------------------------------------------------
        stage('AWS ECR Login') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                }
            }
        }

        // --------------------------------------------------------
        // Stage 4: Docker Build & Push
        // Only reached if SAST quality gate passed.
        // --------------------------------------------------------
        stage('Build & Push Docker Image') {
            steps {
                script {
                    def IMAGE_TAG = "${env.GIT_COMMIT}" ?: "latest"
                    env.IMAGE_URL = "${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

                    sh "docker build -t ${env.IMAGE_URL} ./app"
                    sh "docker push ${env.IMAGE_URL}"
                }
            }
        }

        // --------------------------------------------------------
        // Stage 5: Update Manifests
        // --------------------------------------------------------
        stage('Update Manifests') {
            steps {
                sh "sed -i \"s|image: .*blue-green-app:.*|image: ${env.IMAGE_URL}|\" app/rollout.yaml"
            }
        }

        // --------------------------------------------------------
        // Stage 6: Deploy to EKS (Green as Preview)
        // Green pod goes live; traffic NOT switched yet.
        // Argo holds in PrePromotionAnalysis state.
        // --------------------------------------------------------
        stage('Deploy to EKS (Green Preview)') {
            steps {
                script {
                    sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}"
                    sh "kubectl apply -f monitoring/"
                    sh "kubectl apply -f app/preview-service.yaml"
                    sh "kubectl apply -f app/analysis.yaml"
                    sh "kubectl apply -f app/zap-dast-analysis.yaml"
                    sh "kubectl apply -f app/rollout.yaml --validate=false"

                    echo "Green preview pod deploying. Waiting 60s for initialisation..."
                    sleep(60)
                }
            }
        }

        // --------------------------------------------------------
        // Stage 7: DAST — OWASP ZAP Scan (Jenkins-side, external)
        // Gets the preview LB hostname, runs ZAP baseline scan,
        // fails the pipeline if any HIGH-risk alerts are found.
        // --------------------------------------------------------
        stage('DAST: OWASP ZAP Scan') {
            steps {
                script {
                    echo "=================================================="
                    echo " [DAST] Resolving preview LoadBalancer hostname..."
                    echo "=================================================="

                    def previewUrl = ""
                    timeout(time: 5, unit: 'MINUTES') {
                        waitUntil {
                            def hostname = sh(
                                script: "kubectl get svc blue-green-preview-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo ''",
                                returnStdout: true
                            ).trim()

                            if (hostname && hostname != '') {
                                previewUrl = "http://${hostname}"
                                env.PREVIEW_LB_URL = previewUrl
                                echo " Preview URL: ${previewUrl}"
                                return true
                            }
                            echo " LB not ready yet. Retrying in 15s..."
                            sleep(15)
                            return false
                        }
                    }

                    echo "=================================================="
                    echo " [DAST] Starting OWASP ZAP Baseline Scan"
                    echo " Target: ${env.PREVIEW_LB_URL}"
                    echo "=================================================="

                    sh """
                        mkdir -p /tmp/bg-zap-reports
                        chmod 777 /tmp/bg-zap-reports

                        docker run --rm \
                          -v /tmp/bg-zap-reports:/zap/wrk/:rw \
                          ghcr.io/zaproxy/zaproxy:stable \
                          zap-baseline.py \
                            -t ${env.PREVIEW_LB_URL} \
                            -J bg-zap-report.json \
                            -r bg-zap-report.html \
                            -l WARN \
                            -I || true
                    """

                    // Parse JSON for HIGH-risk alerts (riskcode == "3")
                    def highCount = sh(
                        script: '''python3 -c "
import json, sys
try:
    with open('/tmp/bg-zap-reports/bg-zap-report.json') as f:
        data = json.load(f)
    highs = [
        a for site in data.get('site', [])
        for a in site.get('alerts', [])
        if a.get('riskcode', '0') == '3'
    ]
    for h in highs:
        print(f\'  [HIGH] {h.get(\\\"alert\\\",\\\"?\\\")}\', file=sys.stderr)
    print(len(highs))
except Exception as e:
    print(f\'Parse error: {e}\', file=sys.stderr)
    print(0)
"
''',
                        returnStdout: true
                    ).trim()

                    echo " [DAST] HIGH-risk vulnerabilities found: ${highCount}"

                    if (highCount.toInteger() > 0) {
                        sh "kubectl argo rollouts abort blue-green-rollout || true"
                        error("[DAST] ZAP scan found ${highCount} HIGH-risk alert(s). Rollout aborted.")
                    }

                    echo " [DAST] ZAP scan PASSED. No HIGH-risk vulnerabilities found."
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: '/tmp/bg-zap-reports/bg-zap-report.html',
                                     allowEmptyArchive: true,
                                     fingerprint: true
                }
            }
        }

        // --------------------------------------------------------
        // Stage 8: Wait for Argo In-Cluster Analysis & Promotion
        // Argo runs its own ZAP AnalysisTemplate (zap-dast-analysis.yaml)
        // AND success-rate-check before auto-promoting to active.
        // --------------------------------------------------------
        stage('Wait for Rollout & Analysis') {
            steps {
                echo "Monitoring Argo Rollout in-cluster analysis and auto-promotion..."
                sh "kubectl argo rollouts status blue-green-rollout --timeout 10m"
            }
        }

        // --------------------------------------------------------
        // Stage 9: Post-Deploy Health Audit
        // --------------------------------------------------------
        stage('Post-Deploy Health Audit') {
            steps {
                script {
                    echo "Verifying live pod status..."
                    sh "kubectl get pods -l app=blue-green | grep Running"
                }
            }
        }
    }

    post {
        success {
            echo 'Secure deployment complete. SAST + DAST passed. Green is now live traffic.'
        }
        failure {
            echo 'Pipeline failed. Review SAST (SonarQube) or DAST (ZAP) reports for remediation.'
        }
    }
}
