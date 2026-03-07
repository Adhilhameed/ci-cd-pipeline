# 🚀 CI/CD Pipeline — React App to AWS ECS via Jenkins

A production-grade CI/CD pipeline that automatically lints, tests, containerizes, and deploys a React application to AWS ECS (Fargate) using Jenkins.

---

## 📐 Architecture

```
Developer Push
      │
      ▼
┌─────────────┐     ┌──────────────────────────────────────────────┐
│   GitHub    │────▶│              Jenkins Pipeline                  │
│  (trigger)  │     │                                                │
└─────────────┘     │  ① Checkout  →  ② Install  →  ③ Lint         │
                    │       ↓                                        │
                    │  ④ Test + Coverage Report                      │
                    │       ↓                                        │
                    │  ⑤ React Build (npm run build)                │
                    │       ↓                                        │
                    │  ⑥ Docker Build + Push → AWS ECR              │
                    │       ↓                                        │
                    │  ⑦ ECS Rolling Deploy (main branch only)      │
                    └──────────────────────────────────────────────┘
                                         │
                                         ▼
                              ┌──────────────────┐
                              │   AWS ECS Fargate │
                              │  (React + Nginx)  │
                              └──────────────────┘
```

---

## 📁 Project Structure

```
ci-cd-pipeline/
├── app/                        # React application
│   ├── src/
│   │   ├── App.js              # Main component
│   │   └── App.test.js         # Unit + integration tests
│   ├── Dockerfile              # Multi-stage build (Node → Nginx)
│   ├── nginx.conf              # SPA routing + caching config
│   ├── .eslintrc.js            # Lint rules
│   └── package.json
│
├── jenkins/
│   └── Jenkinsfile             # ⭐ Full 7-stage pipeline definition
│
├── scripts/
│   └── deploy.sh               # ECS blue/green-style deploy script
│
└── k8s/
    └── ecs-task-definition.json  # ECS Fargate task template
```

---

## ⚙️ Pipeline Stages

| # | Stage | What It Does |
|---|-------|-------------|
| 1 | **Checkout** | Pulls latest code from Git |
| 2 | **Install** | `npm ci` (clean, reproducible install) |
| 3 | **Lint** | ESLint checks code quality |
| 4 | **Test** | Jest tests + coverage report published to Jenkins |
| 5 | **Build** | `npm run build` → optimised React bundle |
| 6 | **Dockerize** | Multi-stage Docker build + push to AWS ECR |
| 7 | **Deploy** | Rolling ECS update (main branch only) |

---

## 🛠️ Setup Guide

### Prerequisites
- Jenkins server with the following plugins:
  - Pipeline, Git, AnsiColor, HTML Publisher, AWS Credentials
- AWS account with:
  - ECR repository created
  - ECS cluster + service running
  - IAM role for Jenkins with ECR push + ECS deploy permissions
- Docker installed on the Jenkins agent

### Step 1 – Jenkins Credentials
Go to **Jenkins → Manage Jenkins → Credentials** and add:

| ID | Type | Value |
|----|------|-------|
| `aws-credentials` | AWS Credentials | Your AWS Access Key + Secret |

### Step 2 – Create the Jenkins Pipeline Job
1. New Item → **Pipeline**
2. Under *Pipeline*, choose **Pipeline script from SCM**
3. Set SCM to **Git** and enter your repo URL
4. Set *Script Path* to `jenkins/Jenkinsfile`

### Step 3 – Update Environment Variables
Edit `jenkins/Jenkinsfile` and update:
```groovy
AWS_ACCOUNT_ID = 'YOUR_12_DIGIT_ACCOUNT_ID'
AWS_REGION     = 'us-east-1'          // your region
ECS_CLUSTER    = 'your-cluster-name'
ECS_SERVICE    = 'your-service-name'
```

### Step 4 – Bootstrap AWS Resources
```bash
# Create ECR repository
aws ecr create-repository --repository-name react-cicd-app --region us-east-1

# Register initial ECS task definition
aws ecs register-task-definition \
  --cli-input-json file://k8s/ecs-task-definition.json

# Create ECS service (if not already running)
aws ecs create-service \
  --cluster production-cluster \
  --service-name react-app-service \
  --task-definition react-cicd-app \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

### Step 5 – Trigger the Pipeline
Push to `main` — Jenkins picks it up within 5 minutes (or configure a GitHub webhook for instant triggers).

---

## 🐳 Docker Details

The Dockerfile uses a **multi-stage build**:

- **Stage 1 (builder):** Node.js 18 Alpine — installs deps, runs `npm run build`
- **Stage 2 (runtime):** Nginx 1.25 Alpine — only ~25MB final image

Benefits: no Node.js in production, smaller attack surface, faster pulls.

---

## 🔒 IAM Permissions Required

Minimum Jenkins IAM policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:WaitServicesStable"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["iam:PassRole"],
      "Resource": "arn:aws:iam::*:role/ecsTaskExecutionRole"
    }
  ]
}
```

---

## 💡 Key Design Decisions

| Decision | Reason |
|----------|--------|
| `npm ci` instead of `npm install` | Reproducible builds, fails if lockfile is out of sync |
| Coverage threshold (70%) | Pipeline fails if test coverage drops — enforces quality |
| `--cache-from latest` in Docker build | Speeds up builds by reusing unchanged layers |
| Deploy only on `main` branch | Prevents accidental deploys from feature branches |
| `aws ecs wait services-stable` | Pipeline doesn't succeed until ECS confirms healthy tasks |
| Build number in image tag | Every image is uniquely traceable, easy rollbacks |

---

## 🔄 Rolling Back

To roll back to a previous build:
```bash
# List recent task definitions
aws ecs list-task-definitions --family-prefix react-cicd-app

# Update service to a previous revision
aws ecs update-service \
  --cluster production-cluster \
  --service react-app-service \
  --task-definition react-cicd-app:PREVIOUS_REVISION
```

---

## 📊 What to Show Recruiters

> *"I built a Jenkins pipeline that automatically lints and tests a React app on every push,
> packages it into a multi-stage Docker container, pushes to AWS ECR, and does a rolling
> deploy to ECS Fargate — with no manual steps after the commit."*

**Skills demonstrated:** Jenkins, Docker, AWS ECR, AWS ECS/Fargate, Bash scripting, ESLint, Jest, CI/CD best practices, IAM security.
