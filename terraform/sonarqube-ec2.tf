
# ============================================================
# DevOps-Blue-Green | Security Infrastructure
# SonarQube SAST Server - Dedicated t3.medium EC2 Instance
# ============================================================

# --- Data Sources ---
data "aws_ami" "sonarqube_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security Group for SonarQube ---
resource "aws_security_group" "sonarqube_sg" {
  name        = "bg-sonarqube-sg"
  description = "Security group for the DevOps-Blue-Green SonarQube SAST instance"
  vpc_id      = module.vpc.vpc_id

  # Allow SonarQube UI access from Jenkins EC2 (and optionally a developer IP)
  ingress {
    description = "SonarQube Web UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your IP in production
  }

  # SSH access for administration
  ingress {
    description = "SSH Admin Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict to your admin IP in production
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "bg-sonarqube-sg"
    Project = "DevOps-Blue-Green"
    Role    = "SAST-Security"
  }
}

# --- IAM Instance Profile for SonarQube EC2 ---
resource "aws_iam_role" "sonarqube_role" {
  name = "bg-sonarqube-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name    = "bg-sonarqube-ec2-role"
    Project = "DevOps-Blue-Green"
    Role    = "SAST-Security"
  }
}

resource "aws_iam_instance_profile" "sonarqube_profile" {
  name = "bg-sonarqube-instance-profile"
  role = aws_iam_role.sonarqube_role.name
}

# Attach SSM policy for parameter store access (for token retrieval)
resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# --- SonarQube EC2 Instance ---
resource "aws_instance" "bg_sonarqube_server" {
  ami                    = data.aws_ami.sonarqube_amazon_linux.id
  instance_type          = "t3.medium" # Dedicated to avoid contention with Jenkins/Monitoring node
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = true    # Required to make SonarQube UI reachable on port 9000
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.sonarqube_profile.name
  # key_name removed — SonarQube is accessed via web UI on port 9000 only.
  # For emergency console access, use AWS Systems Manager Session Manager.

  # SonarQube requires at least 2GB RAM; t3.medium provides 4GB.
  # Elasticsearch (bundled with SonarQube) also requires vm.max_map_count ≥ 262144.
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # --- System Tuning for Elasticsearch (bundled in SonarQube) ---
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    sysctl -p

    # --- Install Docker ---
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user

    # --- Create SonarQube data directories ---
    mkdir -p /opt/sonarqube/data
    mkdir -p /opt/sonarqube/logs
    mkdir -p /opt/sonarqube/extensions
    chown -R 1000:1000 /opt/sonarqube

    # --- Run SonarQube Community Edition via Docker ---
    docker run -d \
      --name bg-sonarqube \
      --restart always \
      -p 9000:9000 \
      -v /opt/sonarqube/data:/opt/sonarqube/data \
      -v /opt/sonarqube/logs:/opt/sonarqube/logs \
      -v /opt/sonarqube/extensions:/opt/sonarqube/extensions \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      sonarqube:10.4-community

    echo "SonarQube container started. Access at http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):9000"
    echo "Default credentials: admin / admin (change immediately!)"
  EOF

  tags = {
    Name    = "bg-sonarqube-server"
    Project = "DevOps-Blue-Green"
    Role    = "SAST-Security"
    Phase   = "Phase-4-Security"
  }
}

# --- Outputs ---
output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube SAST server"
  value       = aws_instance.bg_sonarqube_server.public_ip
}

output "sonarqube_url" {
  description = "SonarQube UI URL"
  value       = "http://${aws_instance.bg_sonarqube_server.public_ip}:9000"
}
