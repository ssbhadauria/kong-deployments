output "proxy_nlb_dns" {
  description = "Public DNS of the proxy NLB. Hit KongAir at http://<this>/ once routes exist."
  value       = aws_lb.proxy.dns_name
}

output "ecs_cluster" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service" {
  value = aws_ecs_service.dp.name
}

output "control_plane_id" {
  value = local.control_plane_id
}

# Consumed by stack 25: Kong resolves {vault://...} refs at runtime using the
# TASK role, so stack 25 attaches its GetSecretValue policy to this role.
output "task_role_name" {
  value = aws_iam_role.task.name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
