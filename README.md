# AWS WordPress Highly Available & Scalable Cloud Architecture
## Semester Final Project - Cloud Computing Course

### 1. Project Overview
This semester final project demonstrates the design and deployment of an enterprise-grade, highly available, and elastically scalable web infrastructure on AWS using Terraform. 

The project consolidates core cloud design principles addressed throughout the semester—ranging from stateless computing and multi-AZ partitioning to layer-7 traffic distribution, private network isolation, and dynamic scaling mechanisms.

### 2. Core Architectural Pillars

#### 1. Compute & Elastic Autoscaling (EC2 + ASG)
Instead of relying on statically provisioned backend servers, the application layer uses an **AWS Auto Scaling Group (ASG)** tied to an active **Launch Template**. The servers dynamically scale in or out based on performance requirements.

#### 2. Managed Database Separation (RDS MySQL)
Database management is offloaded from local server storage onto a managed, isolated **Amazon RDS MySQL** instance running privately across multiple subnets, ensuring clean data consistency.

#### 3. Shared Media Storage (Amazon S3)
Because Auto Scaling components are completely ephemeral and can be terminated at any moment, local storage cannot persist user-uploaded media files. All assets and media uploads are offloaded directly onto an external persistent **Amazon S3 Bucket**.

#### 4. Intelligent Traffic Routing (ALB)
An internet-facing **Application Load Balancer (ALB)** acts as the unique entry point, automatically executing round-robin load distribution and monitoring backend health checks.

### 3. Repository Directory Structure
```text
.
├── .gitignore               # Excludes tracking states and temporary credential files
├── README.md                # Quickstart guide and architectural definition
├── main.tf                  # Main structural blueprint (VPC, Security, ALB, ASG, RDS, S3)
├── variables.tf             # Declarations of input constraints and configurations
├── outputs.tf               # Structural outputs (Final ALB DNS routing address)
├── user-data.sh             # Dynamic deployment wrapper (Installs Apache, PHP, WP, maps RDS)
├── report.md                # Integrated final analysis, metric results, and command log
└── finished.txt             # Mandatory lab completion marker
```

### 4. Prerequisites

Terraform CLI: Installed and canonized (>= 1.5.0).
AWS CLI v2: Connected to active AWS Academy temporary shell sessions.
AWS Temporary Tokens: Loaded into active environment buffers (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN).

### 5. Deployment & Quickstart Guide

To stand up the infrastructure and verify its high-availability configuration, execute the following block:

```bash
# 1. Load your AWS Academy Temporary Sessions
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_SESSION_TOKEN="your-session-token"

# 2. Set the private RDS master password passphrase
export TF_VAR_db_master_password="YourSecurePassword2026!"

# 3. Provision the Cloud Stack
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

### 6. Verification and E2E Application Testing
Once the deployment concludes (approx. 4-5 minutes), run the automated curl payload test against the Application Load Balancer endpoint to verify the operational state of the stateless compute pool and its secure connection to the backend RDS database cluster:

```bash
# Capture the dynamic entrypoint and query the cluster
ALB_DNS=$(terraform output -raw wordpress_alb_url)
curl -s "${ALB_DNS}"
```

Expected Healthy Response:

```bash
<h1>WordPress HA Cluster Node</h1>
<p>Status: Operating Healthy</p>
<p>Database Destination Host: wp-ha-final-db-cluster...rds.amazonaws.com</p>
```

7. Teardown & Resource Decommissioning
To avoid running up maintenance fees or burning academic cloud credits, purge all tracking footprints directly using:

```bash
terraform destroy -auto-approve
```
