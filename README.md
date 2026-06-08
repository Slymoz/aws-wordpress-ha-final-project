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
