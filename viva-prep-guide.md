# 🚀 Ultimate DevOps Viva Prep Guide

This guide is your holy grail for passing the viva. It breaks down your entire Blue-Green deployment project file-by-file, highlights the exact code the examiner will ask about, and explains *why* you chose this stack over the alternatives.

---

## Part 1 & 2: File Roles & Code Deep Dives

### 📂 1. `terraform/main.tf`
**Role:** Provisions the physical infrastructure on AWS (VPC networking and EKS Cluster).
**Important Sections:**
```hcl
module "eks" {
  ...
  eks_managed_node_groups = {
    nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 3
      instance_types = ["t3.micro"]
      
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
      }
```
*   **What it does:** Creates an EKS node group with auto-scaling capabilities (1 to 3 servers).
*   **Why we use it:** Instead of manually booting EC2 servers, Terraform automates the creation of a managed Kubernetes cluster. The `tags` are crucial because they tell the Kubernetes Cluster Autoscaler that it has permission to physically scale these AWS nodes up or down.

### 📂 2. `app/rollout.yaml`
**Role:** The absolute core of the project. Replaces a standard Kubernetes `Deployment` with an internal Argo `Rollout` object to enable Blue-Green traffic routing.
**Important Sections:**
```yaml
  strategy:
    blueGreen:
      activeService: blue-green-service
      previewService: blue-green-preview-service
      autoPromotionEnabled: true
      prePromotionAnalysis:
        templates:
          - templateName: success-rate-check
```
*   **What it does:** Defines the deployment strategy. It assigns user traffic to the `activeService`, pushes internal testing traffic to `previewService`, and runs an analysis check *before* promoting the traffic (`prePromotionAnalysis`).
*   **Why we use it:** Native Kubernetes rolling updates slowly replace pods one by one, which can cause mixed-version traffic. Blue-Green strictly separates the old and new environments, allowing 100% zero-downtime and instant rollbacks.

### 📂 3. `app/analysis.yaml`
**Role:** Defines the health-check logic that validates if a new release is safe to promote to real users.
**Important Sections:**
```yaml
      successCondition: result == "200"
      provider:
        web:
          url: "http://blue-green-preview-service.default.svc.cluster.local/"
```
*   **What it does:** Continuously queries the `previewService` (the new, unreleased Green environment) and only passes if the server responds with a perfect HTTP `200 OK`.
*   **Why we use it:** Without this, Argo would blindly push broken code to users. This automates the quality assurance check. Using the `.cluster.local` DNS suffix ensures the health check stays inside the secure internal Kubernetes network without going out to the internet.

### 📂 4. `app/deployment.yaml` & `app/preview-service.yaml`
**Role:** Defines the networking Services that route traffic to the pods.
**Important Sections:**
```yaml
  type: LoadBalancer
  selector:
    app: blue-green
```
*   **What it does:** Provisions a physical AWS Elastic Load Balancer (ELB) and routes traffic via port 80 to the pods labeled `app: blue-green`.
*   **Why we use it:** A standard `ClusterIP` service is completely invisible to the outside internet. `LoadBalancer` automatically talks to AWS and gives us a public URL (`xyz.us-east-1.elb.amazonaws.com`) for the examiner to click.

### 📂 5. `.github/workflows/deploy.yml`
**Role:** The CI/CD pipeline that automates building and pushing code.
**Important Sections:**
```yaml
      - name: Update Rollout Manifest
        run: |
          sed -i "s|image: 593927188565.*|image: ${{ env.IMAGE_URL }}|" app/rollout.yaml
```
*   **What it does:** Uses standard Linux `sed` logic to dynamically inject the newly generated Docker Image Tag (based on the git commit hash) into the Rollout file before applying it to Kubernetes.
*   **Why we use it:** Hardcoding image tags (like `app:v4`) requires manual updates every single time code changes. By injecting the `github.sha`, every `git push` produces a 100% unique, traceable image tag automatically.

### 📂 6. `app/Dockerfile`
**Role:** Packages the front-end application into an isolated container.
**Important Sections:**
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
```
*   **What it does:** Uses a lightweight Nginx web server base image and injects your custom `index.html` file into the default serving directory.
*   **Why we use it:** Instead of configuring EC2 instances with Apache manually, this ensures the website runs identically on your laptop, the GitHub runner, and the highly-scaled AWS cloud. `alpine` is used because it's a vastly smaller, more secure Linux distribution compared to standard Ubuntu.

---

## Part 3: Tool Alternatives & Why You Didn't Use Them

Examiners love asking *"Why did you use X instead of Y?"* Here are the bulletproof answers:

### 1. Terraform vs. AWS CloudFormation / Ansible
*   **What they are:** CloudFormation is AWS's native IaC (Infrastructure as Code) tool. Ansible is an imperative configuration tool.
*   **Why you chose Terraform:** Terraform is **cloud-agnostic**. If the company decides to migrate from AWS to Google Cloud (GCP) tomorrow, CloudFormation is completely useless. Terraform can deploy to any cloud provider using different provider blocks. Furthermore, Terraform maintains a `state file` to accurately track infrastructure, whereas Ansible struggles with tracking deleted resources.

### 2. Argo Rollouts vs. Flagger / Jenkins Deploy
*   **What they are:** Flagger is another progressive delivery tool by Weaveworks. Jenkins is a traditional CI/CD server.
*   **Why you chose Argo:** Argo uses **Kubernetes-native Custom Resource Definitions (CRDs)**. This means you interact with Argo using `kubectl` natively. Flagger relies heavily on complex Service Mesh integrations (like Istio/Linkerd) which adds massive, unnecessary overhead for a standard Blue-Green deployment. Jenkins is old, clunky, and running scripts is error-prone compared to Argo's declarative "reconciliation loop" model.

### 3. GitHub Actions vs. Jenkins CI 
*   **What they are:** Jenkins requires dedicated servers to host its CI environment.
*   **Why you chose GitHub Actions:** GitHub Actions is **serverless and fully managed**. With Jenkins, a DevOps engineer has to securely host a Jenkins server, update Java plugins, and manage worker nodes. GitHub actions completely eliminates maintenance scaling—you simply provide a `.yml` file and GitHub provides immediate compute power on demand.

### 4. AWS EKS vs. Minikube / EC2 Instances
*   **What they are:** Minikube is a local test environment. EC2 is raw, unmanaged virtual machines.
*   **Why you chose AWS EKS:** Managing the Kubernetes "Control Plane" (API server, etcd database) is insanely difficult in a production environment (called "Kubernetes The Hard Way"). EKS fully abstracts the Control Plane away, making it Highly Available and fault-tolerant by default. EC2 deployments would require manually installing Docker, setting up load balancing, and handling scaling scripts—EKS does it automatically.

### 5. Blue-Green Strategy vs. Canary or Rolling Updates
*   **What they are:** Canary releases 5% of traffic to the new version slowly. Rolling updates kill one old pod and spin up one new pod continuously until finished.
*   **Why you chose Blue-Green:** Rolling updates result in a scenario where 50% of users see the new site and 50% see the old site for several minutes, breaking API continuity. Canary is great for large microservices, but incredibly complex to configure metrics for. Blue-Green offers a **clean cutover**—100% of the traffic switches simultaneously, ensuring no users experience a mixed application state.
