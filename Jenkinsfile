pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = '593927188565.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO = 'blue-green-app'
        CLUSTER_NAME = 'blue-green-cluster'
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
        PATH = "/var/lib/jenkins/bin:${env.PATH}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('AWS ECR Login') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                }
            }
        }
        
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
        
        stage('Update Manifests') {
            steps {
                sh "sed -i \"s|image: .*blue-green-app:.*|image: ${env.IMAGE_URL}|\" app/rollout.yaml"
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                sh "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}"
                
                // Ensure Monitoring Stack is up
                sh "kubectl apply -f monitoring/namespace.yaml"
                sh "kubectl apply -f monitoring/"

                // Deploy App
                sh "kubectl apply -f app/preview-service.yaml"
                sh "kubectl apply -f app/analysis.yaml"
                sh "kubectl apply -f app/rollout.yaml --validate=false"
            }
        }

        stage('Wait for Rollout & Analysis') {
            steps {
                echo "Monitoring Argo Rollout promotion..."
                sh "kubectl argo rollouts status blue-green-rollout --timeout 10m"
            }
        }

        stage('Post-Deploy Health Audit') {
            steps {
                script {
                    echo "Querying Prometheus for final deployment health..."
                    // This checks if the active pods are 'up' according to Prometheus
                    sh "curl -s 'http://prometheus-service.monitoring.svc.cluster.local:8080/api/v1/query?query=up{app=\"blue-green\"}'"
                }
            }
        }
    }
    
    post {
        success {
            echo 'Deployment triggered successfully. Argo Rollouts is now evaluating the Blue-Green swap on EKS.'
        }
        failure {
            echo 'Deployment pipeline failed.'
        }
    }
}
