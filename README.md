End-to-End Elastic CI/CD Pipeline: Kubernetes Blue-Green Deployment
This project demonstrates a production-grade DevOps workflow implementing Infrastructure-as-Code (IaC), GitOps, and Cloud Elasticity. It features a self-scaling Kubernetes cluster on AWS that performs zero-downtime Blue-Green deployments.

🚀 Key Features
Infrastructure-as-Code: Provisioned an AWS EKS (v1.31) cluster using Terraform.

Automated CI/CD: Deployed a custom Jenkins CI/CD server on AWS EC2 to process GitHub Webhooks, build Docker images, and trigger Argo Rollouts deployments.

Zero-Downtime Strategy: Implemented a Blue-Green Deployment pattern to ensure seamless version transitions.

Dynamic Cloud Scaling: Configured Cluster Autoscaler to automatically provision AWS EC2 nodes based on real-time pod demand.

Resource Optimization: Right-sized Kubernetes manifests to operate efficiently within t3.micro resource constraints.

🛠 Tech Stack
Cloud: Amazon Web Services (EKS, EC2, IAM, VPC, ELB)

IaC: Terraform

Containerization: Docker & Docker Hub

Orchestration: Kubernetes

CD & Strategy: ArgoCD / Argo Rollouts

CI/CD Engine: Jenkins (Self-hosted on AWS EC2)

📈 The Architecture
The pipeline follows a strict GitOps flow:

Developer Push: A code change triggers a Webhook from GitHub.

CI Engine: The self-hosted Jenkins server on AWS EC2 catches the payload and runs the pipeline.

Build & Push: Jenkins builds a new Docker image and pushes it to the AWS ECR registry.

Declarative Apply: Jenkins updates the Kubernetes manifests and automatically applies them to EKS, triggering the Argo Rollout.

Blue-Green Cutover: A new "Green" environment is created. Once health checks pass, traffic is shifted 100% from "Blue" to "Green."

Autoscaling: If the new version requires more resources than the current nodes provide, the Cluster Autoscaler triggers an AWS Auto Scaling Group (ASG) expansion.

🔧 Challenges & Resolutions
Resource Exhaustion: Identified and resolved "Insufficient Memory" errors by tuning pod resource requests/limits to fit t3.micro nodes.

IAM Authorization: Debugged AccessDenied errors in the Autoscaler by mapping specific AWS IAM policies (AutoScalingFullAccess) to the Kubernetes Service Account.

Service Mesh/Networking: Configured AWS Load Balancers to route traffic dynamically between stable and preview versions during rollouts.

🏁 Final Results
The project successfully automated the transition from V1 through V7, with the final state showing:

Stable Version: V7

Node Count: 3 (Elasticly scaled from 2)

Deployment Status: 100% Healthy
