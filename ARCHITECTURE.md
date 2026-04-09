# Blue-Green Architecture with Jenkins (Updated)

Here is your finalized, end-to-end architecture diagram representing the complete cloud infrastructure after migrating to Jenkins. You can use this diagram to visually explain the flow of data and deployments during your Viva.

```mermaid
graph TD
  %% Core Entities
  Dev(("👨‍💻 Developer"))
  GH["🐙 GitHub Repository"]
  Jenkins["☕ Jenkins CI/CD<br/>(Running on AWS EC2)"]
  ECR["🗄️ AWS ECR<br/>(Docker Registry)"]
  
  %% EKS Boundary
  subgraph AWS EKS Cluster [☁️ AWS EKS Cluster - Built via Terraform]
    Argo["🐙 Argo Rollouts Controller"]
    
    subgraph Load Balancers
      ALB_Active["🟢 Active Service (ALB)"]
      ALB_Preview["🟡 Preview Service (ALB)"]
    end
    
    subgraph Application Pods
      Pod_Stable["🔵 Stable Pods (V5)"]
      Pod_Preview["🟢 New Pods (V6)"]
    end
  end

  Users(("👥 Live Users"))

  %% Step 1: CI Trigger
  Dev -- "1. git push" --> GH
  GH -- "2. Webhook Event" --> Jenkins
  
  %% Step 2: Build & Push
  Jenkins -- "3. Build & push image" --> ECR
  
  %% Step 3: CD Trigger
  Jenkins -- "4. kubectl apply (Rollouts)" --> Argo

  %% Step 4: Argo Orchestration
  Argo -- "5. Pulls new image" --> ECR
  Argo -- "6. Spins up new release" --> Pod_Preview
  
  %% Step 5: Traffic Routing
  ALB_Active -- "Live Traffic" --> Pod_Stable
  ALB_Preview -- "Test Traffic" --> Pod_Preview
  Users -- "100% Traffic" --> ALB_Active
  
  %% Step 6: Automated Analysis
  Argo -. "7. Performs HTTP Health Analysis<br/>on Preview Service" .-> ALB_Preview
  
  %% Step 7: Promotion
  Argo == "8. If Success: Promote Preview to Active" ==> ALB_Active
  Argo == "8. If Failed (500): Scale Down Preview" ==> Pod_Preview
  
  %% Styling
  classDef primary fill:#1e40af,stroke:#60a5fa,stroke-width:2px,color:white;
  classDef secondary fill:#047857,stroke:#34d399,stroke-width:2px,color:white;
  classDef alert fill:#be123c,stroke:#fda4af,stroke-width:2px,color:white;
  
  class Jenkins,Argo primary;
  class Pod_Preview,ALB_Preview secondary;
  class Pod_Stable,ALB_Active primary;
```

### 🧠 How to Explain This Diagram in Your Viva:

1. **The Automation Trigger (Steps 1 & 2):** Point out that the process is entirely hands-off. A `git push` fires a payload over the internet directly to the custom **AWS EC2 Jenkins Server**.
2. **The Build Engine (Steps 3 & 4):** Jenkins acts as the heart of the operation. It builds the Docker container, stores it cleanly in **AWS ECR**, and hands the declarative AWS architecture over to the Kubernetes cluster using `kubectl`.
3. **The Brain (Steps 5 & 6):** **Argo Rollouts** assumes control. It creates the green (preview) infrastructure *without* destroying the blue (stable) infrastructure. It isolates the new code behind the **Preview Load Balancer**.
4. **The Gatekeeper (Steps 7 & 8):** Explain how Argo mathematically verifies the health of the Preview Service via the `health.json` endpoint. If it returns `200`, Argo swaps the networking rules, immediately routing Live Users to the new version with zero downtime. If it returns `500`, Argo effortlessly kills the preview pods and the Live Users are never affected.
