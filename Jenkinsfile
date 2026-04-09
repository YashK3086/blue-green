pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REGISTRY = '593927188565.dkr.ecr.us-east-1.amazonaws.com'
        ECR_REPO = 'blue-green-app'
        CLUSTER_NAME = 'blue-green-cluster'
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
                sh "kubectl apply -f app/analysis.yaml"
                sh "kubectl apply -f app/rollout.yaml --validate=false"
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
