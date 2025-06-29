output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value       = aws_instance.k8s_nodes[0].public_ip
}

output "worker_node_1_public_ip" {
  description = "Public IP of worker node 1"
  value       = aws_instance.k8s_nodes[1].public_ip
}

output "worker_node_2_public_ip" {
  description = "Public IP of worker node 2"
  value       = aws_instance.k8s_nodes[2].public_ip
}

output "all_node_public_ips" {
  description = "List of all public IPs"
  value       = [for instance in aws_instance.k8s_nodes : instance.public_ip]
}
