output "cluster_name" {
  value = aws_eks_cluster.petclinic.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.petclinic.endpoint
}

output "vpc_id" {
  value = aws_vpc.petclinic.id
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}

output "ecr_urls" {
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}