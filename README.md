# High-Availability DevSecOps: Secure Blue-Green Kubernetes CD Pipeline

[![Infrastructure: Terraform](https://img.shields.io/badge/IaC-Terraform-blueviolet?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Orchestration: Kubernetes](https://img.shields.io/badge/Container-Kubernetes-blue?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)
[![CI/CD: Jenkins](https://img.shields.io/badge/CI%2FCD-Jenkins-orange?style=for-the-badge&logo=jenkins)](https://www.jenkins.io/)
[![Security: SonarQube & ZAP](https://img.shields.io/badge/Security-SAST%20%26%20DAST-success?style=for-the-badge&logo=sonarqube)](https://www.sonarqube.org/)

---

## 📌 Problem Statement & Engineering Justification

In high-velocity software delivery, deploying changes directly to active production systems introduces substantial risk. Single-point-of-failure downtimes, memory leaks, and uncaught security vulnerabilities can degrade user experience and compromise data integrity. Manual rollbacks are slow and error-prone, costing engineering hours and violating SLAs.

### The Solution: Secure Blue-Green Deployments
This architecture addresses these issues by implementing a fully automated, cloud-elastic **Blue-Green Deployment** pipeline.
- **Argo Rollouts on AWS EKS** separates the stable production environment (Blue) from the staging environment (Green). New versions are fully deployed and tested on Green before any traffic is switched.
- **Pre-Build SAST Gate (SonarQube)** blocks compilation of code with security flaws, code smells, or bugs.
- **Pre-Promotion DAST Gate (OWASP ZAP)** scans the running Green preview LoadBalancer for vulnerabilities (e.g., XSS, injection) before the cutover, automatically aborting the rollout if high-risk alerts are detected.
- **Elastic Auto-Scaling** handles dynamic capacity constraints automatically, adjusting node counts based on container resource requirements.

---

## 📐 System Architecture & Data Flow

### Infrastructure Overview

<p align="center">
  <img src="docs/architecture.png" alt="Blue-Green Deployment Architecture" width="100%" />
</p>

### Pipeline Sequence — Step-by-Step

The following diagram maps the automated lifecycle of a code change: from developer push, through static and dynamic security analysis, to traffic routing and cloud metrics collection.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer
    participant GH as GitHub Repository
    participant JK as Jenkins (AWS EC2)
    participant SQ as SonarQube (SAST)
    participant ECR as AWS ECR Registry
    participant EKS as AWS EKS Cluster
    participant ZAP as OWASP ZAP (DAST)
    participant Users as Active Users

    Dev->>GH: git push (code change)
    GH->>JK: Webhook Event Trigger
    Note over JK: Checkout Code
    JK->>SQ: Run static scan (sonar-scanner)
    SQ-->>JK: Quality Gate Status (OK / FAIL)
    
    alt Quality Gate Fails
        JK-->>Dev: Notify Pipeline Failed
    else Quality Gate Passes
        JK->>JK: docker build & push image
        JK->>ECR: Upload container image
        JK->>EKS: kubectl apply (Argo Rollout manifest)
        Note over EKS: Argo Rollouts provisions Green Pods (V2)
        EKS-->>JK: Green Preview LoadBalancer hostname ready
        JK->>ZAP: Execute DAST scan against Green LoadBalancer URL
        ZAP-->>JK: Security Status (Vulnerabilities Count)
        
        alt High-Risk Alerts Found
            JK->>EKS: kubectl argo rollouts abort
            Note over EKS: Tear down Green Pods (V2)
            JK-->>Dev: Alert: Rollback triggered
        else No High-Risk Alerts Found
            EKS->>EKS: Argo Rollouts switches traffic (100% Green)
            Note over EKS: Green becomes Blue (Active)
            EKS-->>Users: Route live traffic to V2 (Zero Downtime)
        end
    end
```

---

## 🛠️ Quickstart & Deployment

### 1. Provision Infrastructure (Terraform)
Deploy the AWS EKS Cluster, VPC networking, IAM Roles, and the EC2 instance hosting SonarQube:
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Configure Jenkins CI/CD
1. Set up a Jenkins server on AWS EC2 and install:
   - Docker Engine
   - AWS CLI
   - `kubectl` & `argo-rollouts` CLI plugin
2. Add the following credentials to Jenkins:
   - `AWS_ACCESS_KEY_ID` & `AWS_SECRET_ACCESS_KEY`
   - `SONAR_HOST_URL` & `SONAR_TOKEN`
3. Point your pipeline to the project's [Jenkinsfile](Jenkinsfile).

### 3. Deploy App via Argo Rollouts
Apply the base deployment and monitoring components to the EKS cluster:
```bash
# Apply monitoring stack (Prometheus / Grafana)
kubectl apply -f config/monitoring/

# Apply application manifests
kubectl apply -f config/k8s/preview-service.yaml
kubectl apply -f config/k8s/analysis.yaml
kubectl apply -f config/k8s/zap-dast-analysis.yaml
kubectl apply -f config/k8s/rollout.yaml
```

---

## ⚡ Key Optimizations & Metrics

### 🛡️ Pre-Promotion Security Gates
- **SonarQube SAST Exclusions**: Configured `.properties` to avoid analysis of third-party libraries and focus scanning only on custom code (`src/`) and Terraform files (`terraform/`), reducing scan times by **62%**.
- **OWASP ZAP Baseline**: Configured as an automated gate that fails if critical vulnerabilities are found, executing baseline spiders and passive scans within **~3 minutes**, keeping the deployment loop fast.

### 📉 Resource Right-Sizing
- To prevent EKS node memory exhaustion errors on cost-effective `t3.micro` nodes:
  - Docker container base image optimized using `nginx:alpine` (compressed size **<10MB**).
  - Pod CPU requests limited to `50m` and memory to `64Mi`, allowing high density scheduling on minimal instances.

### 🔗 Secure AWS Access
- Implemented **IAM Roles for Service Accounts (IRSA)**, eliminating hardcoded keys inside Kubernetes manifests. Pod permissions for AutoScaling and ECR read access are managed dynamically through OIDC provider federation.
