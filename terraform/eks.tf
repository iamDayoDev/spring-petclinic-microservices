# ── IAM ROLE FOR EKS CLUSTER ─────────────────────────────────
resource "aws_iam_role" "eks_cluster" {
  name = "petclinic-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ── IAM ROLE FOR NODE GROUP ───────────────────────────────────
resource "aws_iam_role" "eks_nodes" {
  name = "petclinic-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# ── ALL 4 NODE POLICIES (including ECR) ───────────────────────
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ebs" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_nodes.name
}

# ── SECURITY GROUP ────────────────────────────────────────────
resource "aws_security_group" "eks_cluster" {
  name        = "petclinic-eks-sg"
  description = "EKS cluster security group"
  vpc_id      = aws_vpc.petclinic.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "petclinic-eks-sg" }
}

# ── EKS CLUSTER v1.32 ────────────────────────────────────────
resource "aws_eks_cluster" "petclinic" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.32"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
  }
}

# ── EBS CSI DRIVER ADDON ──────────────────────────────────────
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.petclinic.name
  addon_name   = "aws-ebs-csi-driver"
  depends_on   = [aws_eks_cluster.petclinic]
}

# ── NODE GROUP ────────────────────────────────────────────────
resource "aws_eks_node_group" "petclinic" {
  cluster_name    = aws_eks_cluster.petclinic.name
  node_group_name = "petclinic-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.eks_ecr,
    aws_iam_role_policy_attachment.eks_ebs,
    aws_eks_addon.ebs_csi
  ]

  tags = {
    Name        = "petclinic-node-group"
    Environment = var.environment
  }
}