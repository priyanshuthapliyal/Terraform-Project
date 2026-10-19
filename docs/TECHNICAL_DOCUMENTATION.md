# Enterprise 3-Tier AWS Architecture Deep-Dive: Technical Documentation

> **Document Classification:** Engineering Design & Architecture Reference  
> **Author:** Senior Cloud Infrastructure & Terraform Architect  
> **Repository:** `terraform-aws-3tier`  
> **Terraform Compatibility:** `>= 1.5.0` (AWS Provider `~> 5.0`)  

---

## Table of Contents
1. [Executive Summary & Architectural Blueprint](#1-executive-summary--architectural-blueprint)
2. [Network Architecture (VPC & Subnet Topology)](#2-network-architecture-vpc--subnet-topology)
3. [Zero-Trust Security & Network Microsegmentation](#3-zero-trust-security--network-microsegmentation)
4. [Identity, Access Management (IAM) & Host Hardening](#4-identity-access-management-iam--host-hardening)
5. [Presentation Tier (Application Load Balancer)](#5-presentation-tier-application-load-balancer)
6. [Compute & Application Tier (Auto Scaling Group)](#6-compute--application-tier-auto-scaling-group)
7. [Database Tier (Amazon RDS Multi-AZ & Secrets Management)](#7-database-tier-amazon-rds-multi-az--secrets-management)
8. [Observability, Alerting & SRE Strategy](#8-observability-alerting--sre-strategy)
9. [Remote State Infrastructure & Concurrency Control](#9-remote-state-infrastructure--concurrency-control)
10. [Multi-Environment Management & Directory Isolation](#10-multi-environment-management--directory-isolation)
11. [DevSecOps, Static Code Analysis & Policy-as-Code](#11-devsecops-static-code-analysis--policy-as-code)
12. [Disaster Recovery, Chaos Resilience & Failure Analysis](#12-disaster-recovery-chaos-resilience--failure-analysis)
13. [FinOps & Infrastructure Cost Analysis](#13-finops--infrastructure-cost-analysis)

---

## 1. Executive Summary & Architectural Blueprint

### 1.1 Objective
This architecture delivers an enterprise-grade, highly available, fault-tolerant, and secure 3-tier web application platform on Amazon Web Services (AWS) managed entirely via Infrastructure as Code (IaC) using HashiCorp Terraform.

### 1.2 The 3-Tier Architectural Model
```mermaid
flowchart TD
    subgraph Internet ["Public Internet"]
        Users["Global End Users (HTTPS / TLS 1.3)"]
    end

    subgraph AWS_VPC ["Custom VPC: 10.0.0.0/16 (Dev) | 10.2.0.0/16 (Prod)"]
        IGW["Internet Gateway (IGW)"]

        subgraph Tier_1 ["Tier 1: Presentation (Public Subnets: 10.0.1.0/24 & 10.0.2.0/24)"]
            ALB["Application Load Balancer (Dual-AZ Managed Nodes)"]
            NAT_A["NAT Gateway AZ-A (EIP A)"]
            NAT_B["NAT Gateway AZ-B (EIP B)"]
        end

        subgraph Tier_2 ["Tier 2: Application Compute (Private App Subnets: 10.0.11.0/24 & 10.0.12.0/24)"]
            ASG["Auto Scaling Group (2 to 8 EC2 Instances)"]
            EC2_A["EC2 Worker AZ-A\n(Private IP Only)"]
            EC2_B["EC2 Worker AZ-B\n(Private IP Only)"]
        end

        subgraph Tier_3 ["Tier 3: Database Storage (Isolated Private DB Subnets: 10.0.21.0/24 & 10.0.22.0/24)"]
            RDS_Primary["Amazon RDS PostgreSQL 16 (AZ-A Primary Writer)"]
            RDS_Standby["Amazon RDS PostgreSQL 16 (AZ-B Synchronous Replica)"]
        end
    end

    Users -->|TCP 80 / 443| IGW
    IGW --> ALB
    ALB -->|TCP 8080 (alb-sg)| EC2_A & EC2_B
    EC2_A & EC2_B -->|TCP 5432 (app-sg)| RDS_Primary
    RDS_Primary -.->|EBS Synchronous Block Replication| RDS_Standby

    EC2_A -->|Outbound HTTPS (TCP 443)| NAT_A
    EC2_B -->|Outbound HTTPS (TCP 443)| NAT_B
    NAT_A & NAT_B --> IGW
```

### 1.3 Core Engineering Tenets
* **Strict Least Privilege**: No resource has broader network or IAM access than strictly needed to perform its function.
* **Failure Domain Independence**: No single component outage (instance, NAT gateway, disk volume, or entire Availability Zone) can compromise platform uptime.
* **Immutability & Reproducibility**: Zero manual configuration in the AWS Management Console; 100% of resources are declared, versioned, and applied through Terraform.

---

## 2. Network Architecture (VPC & Subnet Topology)

### 2.1 What We Do
* Provision a custom AWS VPC with DNS Hostnames and DNS Resolution enabled.
* Query operational Availability Zones dynamically using `data.aws_availability_zones.available`.
* Partition the `/16` CIDR block into six contiguous `/24` subnets across two distinct AZs:
  - Two **Public Subnets** (`10.0.1.0/24`, `10.0.2.0/24`).
  - Two **Private Application Subnets** (`10.0.11.0/24`, `10.0.12.0/24`).
  - Two **Private Database Subnets** (`10.0.21.0/24`, `10.0.22.0/24`).
* Attach an Internet Gateway (IGW) to the VPC.
* Provision AWS Elastic IPs and NAT Gateways.
* Build three isolated Route Table sets with explicit subnet associations.

### 2.2 Why We Do It (Design Rationale)
1. **Dynamic AZ Discovery vs. Hardcoding**: Hardcoding zone names such as `us-east-1a` is an anti-pattern because AWS accounts map letter identifiers to physical hardware clusters randomly. Using dynamic data sources with an `opt-in-not-required` filter guarantees that Terraform only provisions subnets in operational data centers that support all services.
2. **Subnet Mathematical Sizing (`cidrsubnet`)**:
   - We use `/24` subnets yielding $256 - 5 = 251$ usable IP addresses per subnet.
   - Using offsets (`+1`, `+2` for public, `+11`, `+12` for app, `+21`, `+22` for DB) leaves predictable buffer zones (`10.0.3.0/24`–`10.0.10.0/24`) for caching clusters (ElastiCache), container nodes (EKS), or Transit Gateway attachments without causing IP address overlap.
3. **True Air-Gapped Database Isolation**:
   - `aws_route_table.private_db` contains **only local VPC routing (`10.0.0.0/16 -> local`)**.
   - It possesses **no route to the Internet Gateway and no route to the NAT Gateway**. Even if malicious code or an exploit is executed on the database tier, it cannot open a socket to command-and-control servers or exfiltrate data directly over the web.
4. **NAT Gateway Redundancy (Production HA vs. Dev Cost)**:
   - NAT Gateways are zone-constrained. If a single NAT is deployed in AZ-A and AZ-A loses power, all instances in AZ-B routing through that NAT lose outbound access.
   - In production, we deploy **one NAT Gateway per AZ**. In development, we parameterize `single_nat_gateway = true` to eliminate redundant hourly infrastructure fees during testing.

---

## 3. Zero-Trust Security & Network Microsegmentation

### 3.1 What We Do
* Implement layered firewalls using AWS Security Groups.
* ALB Security Group: Inbound TCP 80/443 from `0.0.0.0/0`; outbound TCP 8080 to `app-sg`.
* Application Security Group: Inbound TCP 8080 strictly from `alb-sg` ID; outbound TCP 5432 to `db-sg` ID; outbound TCP 80/443 to `0.0.0.0/0` via NAT Gateway.
* Database Security Group: Inbound TCP 5432 strictly from `app-sg` ID; outbound restricted.
* Use discrete rule resources (`aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule`) instead of inline blocks.

### 3.2 Why We Do It (Design Rationale)
1. **Security Group Chaining (`referenced_security_group_id`) vs. CIDR Blocks**:
   - CIDR-based firewall rules permit any server assigned an IP within that range to communicate.
   - Security Group Chaining inspects the Elastic Network Interface (ENI) metadata at the hypervisor level. Traffic is permitted **only** if the sending interface is explicitly associated with the authorized Security Group ID, establishing zero-trust network microsegmentation.
2. **Discrete Rule Resources vs. Legacy Inline Blocks**:
   - Legacy inline blocks (`ingress { ... }` inside `aws_security_group`) cause Terraform to encounter circular dependency deadlocks when Security Group A references Security Group B, and Security Group B references Security Group A.
   - Standalone rule resources decouple rule provisioning from the security group container, resolving graph cycle errors and preventing rule-overwriting drift.
3. **Stateful Filtering**:
   - Security groups are stateful. When the ALB sends a request on port 8080 to an EC2 instance, the reverse response is automatically tracked and allowed back, eliminating the need to expose insecure ephemeral port ranges (1024–65535).

---

## 4. Identity, Access Management (IAM) & Host Hardening

### 4.1 What We Do
* Provision an IAM Execution Role with an `ec2.amazonaws.com` trust relationship via `sts:AssumeRole`.
* Attach managed policies `AmazonSSMManagedInstanceCore` and `CloudWatchAgentServerPolicy`.
* Attach a custom least-privilege policy granting `secretsmanager:GetSecretValue` strictly scoped to the project's secret ARN prefix.
* Wrap the role in an `aws_iam_instance_profile` attached to the Launch Template.
* Enforce **IMDSv2** (`http_tokens = "required"`, `http_put_response_hop_limit = 1`).

### 4.2 Why We Do It (Design Rationale)
1. **Elimination of Bastion Hosts (Jump Boxes) and SSH Port 22**:
   - Bastion hosts require opening inbound port 22, distributing private `.pem` SSH keys to engineers, rotating keys, and patching an extra EC2 instance.
   - **AWS Systems Manager (SSM) Session Manager** replaces SSH completely. The SSM Agent connects *outbound* over TLS (port 443) to AWS endpoints via NAT. Port 22 remains closed. Engineers authenticate using corporate SSO/IAM credentials, and all shell commands are recorded in CloudTrail and CloudWatch Logs.
2. **IMDSv2 vs. IMDSv1 (Mitigating SSRF Attacks)**:
   - In IMDSv1, an attacker exploiting a Server-Side Request Forgery (SSRF) vulnerability in the web app could issue a simple `GET http://169.254.169.254/latest/meta-data/iam/security-credentials/` and steal temporary IAM tokens.
   - IMDSv2 mandates a session-oriented exchange requiring a `PUT` request with custom headers to acquire a secret token before querying metadata. Web proxies and SSRF payloads cannot forge custom headers in `PUT` requests, neutralizing metadata exfiltration.
   - `http_put_response_hop_limit = 1` prevents containerized processes or nested virtualization layers from leaking tokens across network boundaries.
3. **IAM Roles vs. Hardcoded AWS Access Keys**:
   - Static access keys stored in configuration files or environment variables can leak into Git or crash dumps.
   - IAM Roles use the AWS Security Token Service (STS) to automatically issue short-lived credentials that rotate every few hours without administrative overhead.

---

## 5. Presentation Tier (Application Load Balancer)

### 5.1 What We Do
* Deploy an internet-facing Application Load Balancer across the public subnets in both AZs.
* Attach the `alb-sg` security group.
* Configure `drop_invalid_header_fields = true`.
* Provision an `aws_lb_target_group` using `target_type = "instance"` on port 8080 with HTTP health checking.
* Set connection draining (`deregistration_delay = 30`).
* Build an HTTP listener (port 80) with dynamic action: redirecting to HTTPS port 443 when an ACM certificate is supplied, or forwarding directly to the target group in dev sandboxes.

### 5.2 Why We Do It (Design Rationale)
1. **Layer 7 Load Balancing**: Unlike Layer 4 NLBs, ALBs inspect HTTP/HTTPS headers, support URL path-based routing (e.g. `/api` vs `/static`), handle SSL termination, and inject `X-Forwarded-For` headers so application servers know the real client IP.
2. **HTTP Desync Defense (`drop_invalid_header_fields = true`)**: Protects backend application servers from HTTP request smuggling vulnerabilities caused by malformed or ambiguous HTTP headers.
3. **Connection Draining Tuning (`deregistration_delay = 30s`)**:
   - The default AWS deregistration delay is 300 seconds (5 minutes).
   - During deployments or autoscaling events, 5 minutes per instance delays CI/CD pipelines unnecessarily.
   - Tuning it to 30 seconds allows existing HTTP requests to complete gracefully while enabling fast, responsive rolling updates.

---

## 6. Compute & Application Tier (Auto Scaling Group)

### 6.1 What We Do
* Resolve the latest official Amazon Linux 2023 AMI dynamically via `data.aws_ami`.
* Create a Launch Template with `associate_public_ip_address = false`.
* Provision an Auto Scaling Group across private application subnets with `min_size = 2`, `desired_capacity = 2`, `max_size = 4` (scalable to 8 in production).
* Configure `health_check_type = "ELB"` with `health_check_grace_period = 300`.
* Add an `instance_refresh` block with rolling strategy.
* Configure `lifecycle { ignore_changes = [desired_capacity] }`.
* Create an `aws_autoscaling_policy` for Target Tracking based on `ASGAverageCPUUtilization` set to 70%.

### 6.2 Why We Do It (Design Rationale)
1. **ELB Health Checks vs. EC2 Status Checks**:
   - `EC2` health checks only detect hypervisor or hardware crashes. If the Python/Node service crashes or deadlocks, EC2 still reports the instance as "Healthy." The ALB will stop routing traffic to it, but the ASG will **never replace it**.
   - `ELB` health checks delegate instance health to the ALB Target Group. If an instance fails HTTP health checks on port 8080, the ASG automatically terminates and replaces it.
2. **Health Check Grace Period (`300s`)**:
   - Prevents an ASG "death spiral." A newly booted instance requires 45–90 seconds to run user data, install dependencies, and start the systemd service. A 300-second grace period ensures the ASG does not terminate booting instances prematurely.
3. **Lifecycle `ignore_changes = [desired_capacity]`**:
   - Target tracking policies dynamically adjust the instance fleet size based on CPU load.
   - If `desired_capacity` is not ignored, subsequent `terraform apply` runs will clobber live autoscaling adjustments, terminating healthy instances serving customer traffic.
4. **Target Tracking vs. Step Scaling**:
   - Target Tracking functions like a thermostat. Instead of manually tuning rigid thresholds, AWS uses continuous proportional math to scale capacity dynamically, maintaining average CPU utilization near 70%.

---

## 7. Database Tier (Amazon RDS Multi-AZ & Secrets Management)

### 7.1 What We Do
* Generate a high-entropy 24-character master password using `random_password`.
* Inject the database connection payload (`host`, `port`, `username`, `password`, `database`) into **AWS Secrets Manager**.
* Provision a Database Subnet Group spanning the private database subnets across AZ-A and AZ-B.
* Create a DB Parameter Group enforcing SSL (`rds.force_ssl = "1"`).
* Provision an `aws_db_instance` (PostgreSQL 16) with `storage_encrypted = true`, `multi_az = true` (in staging/prod), `max_allocated_storage = 100`, and `deletion_protection = true` (in prod).
* Apply `lifecycle { ignore_changes = [password, latest_restorable_time] }`.

### 7.2 Why We Do It (Design Rationale)
1. **The Truth About `sensitive = true`**:
   - Marking a variable as `sensitive = true` only prevents the value from being printed to standard output in CLI logs.
   - **It does NOT encrypt the secret in `terraform.tfstate`.** The state file still stores the password in plaintext JSON.
   - By creating the password programmatically, storing it in AWS Secrets Manager, and ignoring password changes in Terraform lifecycle, applications retrieve credentials dynamically at runtime via IAM.
2. **Synchronous Physical Multi-AZ Replication**:
   - Unlike read replicas which use asynchronous logical replication, RDS Multi-AZ uses synchronous physical block-level replication.
   - Every write transaction is committed to both AZ-A (primary) and AZ-B (standby) before completing. In the event of primary hardware loss, failover completes in 60–120 seconds with **zero data loss (RPO = 0)**.
3. **Storage Auto-Scaling (`max_allocated_storage`)**:
   - If a relational database runs out of disk space, it crashes immediately. Setting `max_allocated_storage = 100` allows AWS to automatically expand EBS storage volumes when disk capacity drops below 10%, preventing storage exhaustion outages.

---

## 8. Observability, Alerting & SRE Strategy

### 8.1 What We Do
* Provision an Amazon SNS Topic (`${project}-${env}-alerts-topic`) for unified alarm dispatching.
* Build high-signal CloudWatch Metric Alarms:
  - `HTTPCode_Target_5XX_Count > 10` (Application code failures).
  - `UnHealthyHostCount >= 1` (Target group host health failures).
  - `CPUUtilization >= 85%` for 6 minutes on the ASG (Compute fleet saturation).
  - `FreeStorageSpace <= 5 GB` on RDS (Disk exhaustion warning).
  - `CPUUtilization >= 80%` on RDS (Database compute saturation).
  - `DatabaseConnections >= 80` (Connection pool exhaustion warning).

### 8.2 Why We Do It (Design Rationale)
1. **Preventing Alert Fatigue (The Four Golden Signals)**:
   - Alerting on low-level noise causes engineers to ignore alerts.
   - Following Google SRE principles, we alert primarily on **Symptoms** (5XX error rates, unhealthy hosts, storage exhaustion) rather than raw infrastructure metrics.
2. **Differentiating Infrastructure vs. Application 5XX**:
   - `HTTPCode_ELB_5XX_Count`: Load balancer failure (no targets, proxy crash).
   - `HTTPCode_Target_5XX_Count`: Backend web server failure (unhandled exceptions, database query errors).
   - Monitoring target 5XX isolates software bugs from network routing failures.
3. **Missing Data Handling (`treat_missing_data`)**:
   - For error rate metrics, missing data indicates zero errors, so we set `treat_missing_data = "notBreaching"` to prevent false alarms during quiet periods.
   - For heartbeat and host health metrics, missing data indicates monitoring failure, so we set `treat_missing_data = "breaching"`.

---

## 9. Remote State Infrastructure & Concurrency Control

### 9.1 What We Do
* Implement an isolated bootstrap configuration in `bootstrap/backend/`.
* Provision a Customer-Managed KMS Key with automatic annual key rotation.
* Provision an S3 Bucket with Versioning, KMS Encryption, Public Access Block, and TLS enforcement.
* Enable S3 Bucket Keys (`bucket_key_enabled = true`).
* Provision an AWS DynamoDB table with `LockID` string partition key in `PAY_PER_REQUEST` billing mode.

### 9.2 Why We Do It (Design Rationale)
1. **Why `.tfstate` Must Never Be in Git**:
   - Storing state in Git leaks plaintext secrets and exposes full network topology.
   - Git cannot lock files. Simultaneous `terraform apply` runs by multiple developers or CI/CD pipelines will corrupt state and orphan cloud resources.
2. **Distributed State Locking via DynamoDB**:
   - Before executing a plan or apply, Terraform acquires an atomic lock entry in DynamoDB.
   - Any concurrent execution is immediately blocked with `Error: Error acquiring the state lock`, preventing state file corruption.
3. **S3 Bucket Keys Cost Optimization**:
   - Standard KMS encryption makes an API call for every single S3 read/write.
   - Enabling `bucket_key_enabled = true` creates a short-lived bucket-level key that reduces KMS API request traffic and costs by up to 99%.

---

## 10. Multi-Environment Management & Directory Isolation

### 10.1 What We Do
* Structure the repository into `environments/dev`, `environments/staging`, and `environments/prod`.
* Implement reusable module composition where environment directories contain only orchestrators.
* Configure non-overlapping CIDR blocks: `10.0.0.0/16` (dev), `10.1.0.0/16` (staging), `10.2.0.0/16` (prod).
* Parameterize environment resilience, sizing, and safety locks.

### 10.2 Why We Do It (Design Rationale)
1. **Directory-per-Environment vs. Workspaces**:
   - Workspaces share the exact same backend bucket and variable structures. An engineer can easily run `terraform destroy` against the wrong workspace by accident.
   - Directory-per-environment enforces hard blast-radius isolation, distinct remote state files, granular IAM access control for CI/CD runners, and clean architectural parameterization without complex ternary HCL logic.
2. **Non-Overlapping CIDRs**:
   - If all environments used `10.0.0.0/16`, connecting them in the future via VPC Peering or Transit Gateway would be impossible due to IP routing conflicts. Distinct CIDRs ensure inter-VPC routing readiness.

---

## 11. DevSecOps, Static Code Analysis & Policy-as-Code

### 11.1 What We Do
* Configure `.tflint.hcl` with the official AWS ruleset.
* Configure `.checkov.yaml` for policy-as-code and compliance scanning.
* Configure `.pre-commit-config.yaml` for automated local git hook validation.

### 11.2 Why We Do It (Design Rationale)
1. **Beyond `terraform validate`**:
   - `terraform validate` only verifies HCL grammar and types; it will pass invalid AWS instance types like `"t3.superlarge"`.
   - `tflint` catches cloud-provider specific errors and deprecated arguments before calling AWS APIs.
2. **Shift-Left Security**:
   - `checkov` and `trivy` scan the infrastructure code against CIS AWS Foundations, SOC 2, and PCI-DSS benchmarks. Catching security flaws during pre-commit prevents insecure configurations from ever reaching cloud runtime.

---

## 12. Disaster Recovery, Chaos Resilience & Failure Analysis

### 12.1 Five Critical Failure Scenarios

```text
┌──────────────────────────────┬──────────────────────────────┬──────────────────────────────┐
│ Failure Scenario             │ System Behavior & Detection  │ Automated Recovery Path      │
├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ 1. EC2 Instance Dies         │ ALB health check fails (502).│ ASG terminates unhealthy     │
│                              │ StatusCheckFailed triggers.  │ instance and launches new node│
├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ 2. Entire AZ Fails (AZ-A)    │ AZ-A instances unreachable.  │ ALB shifts ingress to AZ-B;  │
│                              │ RDS primary fails over.      │ ASG launches nodes in AZ-B;  │
│                              │                              │ RDS promotes standby in AZ-B.│
├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ 3. Sudden Traffic Surge      │ CloudWatch CPU exceeds 70%.  │ Target Tracking scaling adds │
│                              │                              │ EC2 instances up to max_size.│
├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ 4. Primary RDS Node Fails    │ RDS heartbeat fails.         │ Standby in AZ-B promoted;    │
│                              │ DB connections drop briefly. │ CNAME DNS updated (60-120s). │
├──────────────────────────────┼──────────────────────────────┼──────────────────────────────┤
│ 5. NAT Gateway Impairment    │ AZ outbound egress hangs.    │ Dual NAT design ensures AZ-B │
│                              │                              │ remains completely unaffected│
└──────────────────────────────┴──────────────────────────────┴──────────────────────────────┘
```

---

## 13. FinOps & Infrastructure Cost Analysis

### 13.1 Monthly Cost Comparison
* **Development (`dev`)**: ~$78.85 / month (Single NAT, `t3.micro`, single-AZ RDS `db.t4g.micro`, 7-day backups).
* **Production (`prod`)**: ~$265.70 / month (Dual NAT, `t3.medium`, Multi-AZ RDS `db.t4g.medium`, 30-day backups, enhanced monitoring).

### 13.2 Key FinOps Strategies
1. **Graviton Adoption**: Using `t4g` instances for RDS provides ~20% price-to-performance savings over older `t3` x86 instances.
2. **Single NAT Toggle for Sandbox Environments**: Cuts ~$32.85/month per non-production environment.
3. **Teardown Automation**: Verification scripts and clean destruction playbooks ensure non-production environments can be torn down when not in use.

---

## Summary Matrix: The "What" and the "Why"

| Architecture Domain | WHAT We Implemented | WHY We Implemented It |
| :--- | :--- | :--- |
| **Networking** | Custom VPC, 6 subnets across 2 AZs, isolated DB route tables. | High availability, contiguous CIDR allocations, zero internet egress for database tier. |
| **Security Groups** | Chained security group rules referencing IDs with discrete resources. | Zero-trust microsegmentation, eliminates circular dependency deadlocks. |
| **IAM** | Execution role, SSM Session Manager, IMDSv2 enforced. | Eliminates bastion jump boxes, closes port 22, defends against SSRF token theft. |
| **Load Balancing** | Internet-facing ALB, multi-AZ, 30s connection draining. | Layer 7 routing, SSL termination, zero-downtime rolling deployments. |
| **Compute / ASG** | Dynamic AMI, ELB health checks, Target Tracking scaling, 300s grace period. | Self-healing application tier, auto-replaces crashed processes, handles load spikes. |
| **Database** | Amazon RDS PostgreSQL Multi-AZ, Secrets Manager integration. | Synchronous replication (RPO = 0), automatic failover, zero plaintext secrets in code or state. |
| **Observability** | CloudWatch metric alarms (5xx errors, unhealthy hosts, CPU, storage). | High-signal alerting on user-impacting symptoms, prevents alert fatigue. |
| **State Management** | S3 bucket + KMS encryption + DynamoDB distributed locking table. | Eliminates state corruption, prevents concurrent apply races, safeguards secrets. |
| **Environments** | Reusable modules instantiated in `dev`, `staging`, and `prod` with non-overlapping CIDRs. | Hard blast-radius isolation, DRY code, prevents IP conflicts during future peering. |
| **Quality & Policy** | TFLint, Checkov, Trivy, Git pre-commit hooks. | Shift-left security, validates provider schemas and compliance before cloud apply. |
