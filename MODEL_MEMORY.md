# 🧠 Model Memory - Blue-Green Deployment Project

This file serves as a persistent context for the AI assistant (Antigravity) to maintain continuity across sessions.

## 🚀 Project Overview
**Goal:** Implement a production-grade Blue-Green deployment pipeline on AWS EKS using Jenkins and Argo Rollouts.
**Repository:** `devops-blue-green`

## 🛠 Tech Stack
- **Cloud:** AWS (EKS v1.31, ECR, EC2, IAM)
- **IaC:** Terraform
- **CI/CD:** Jenkins (Self-hosted on AWS EC2)
- **GitOps/Scaling:** Argo Rollouts & Cluster Autoscaler
- **Runtime:** Docker & Kubernetes

## 🚀 Monitoring Integrated (2026-04-14)
- [x] Jenkinsfile updated with Prometheus Health Audit (Option 3).
- [x] Monitoring stack deployment automated in `Deploy to EKS` stage.
- [x] Verified: App manifests (`rollout.yaml`, `analysis.yaml`) are Prometheus-ready.
- [x] Verified: Service discovery naming matches between `monitoring` and `default`.

## 📂 Key Architecture & Files
- `Jenkinsfile`: CI pipeline (Checkout -> Build -> Push to ECR -> Update `rollout.yaml` -> Deploy).
- `app/rollout.yaml`: Defines the Argo Rollout strategy with analysis and preview services.
- `app/analysis.yaml`: Metric-based health checks for automated promotion.
- `terraform/main.tf`: EKS cluster provisioning.
- `ARCHITECTURE.md`: Visual Mermaid diagrams of the flow.

## 📝 Current Project Status (V7)
- **Successful Migration:** Moved from GitHub Actions to Jenkins for CI.
- **Scaling Fixed:** Cluster Autoscaler is functional (IAM policies mapped).
- **Resource Tuning:** Pod limits adjusted to fit `t3.micro` nodes.
- **Version:** Currently targeting V7 stabilization.

## 📋 Common Commands
```bash
# Update Kubeconfig
aws eks update-kubeconfig --name blue-green-cluster --region us-east-1

# Monitor Rollout
kubectl get rollouts
kubectl argo rollouts get rollout blue-green-rollout

# Check Autoscaler Logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

---
*Last updated: 2026-04-14 21:43*

## 🎯 Next Objective: Monitoring (Phase 3)
- **Status:** Planning & Initializing.
- **Goal:** Real-time health monitoring of Blue-Green deployments.
- **Components:** Prometheus, Grafana, Alertmanager.
- **Constraints:** Must stay under resource limits for `t3.micro` nodes.

## 🚧 Current Activity
- **Terraform:** `apply` currently running to provision/re-sync the EKS cluster.
- **Monitoring Architecture:** Preparing lightweight YAML manifests in `/monitoring/`.

## 📋 Monitoring Plan
1. **Prometheus:** Deploy with minimal retention to save disk/memory.
2. **Alertmanager:** Configure for critical failure notifications.
3. **Grafana:** Provision with a pre-configured dashboard for Blue-Green comparisons.

