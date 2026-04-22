output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnets used by the ASG"
}

output "launch_template_id" {
  value       = aws_launch_template.app.id
  description = "Launch template used by the ASG"
}

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.main.name
  description = "Auto Scaling Group name (for Console / CLI testing)"
}

output "scale_out_policy_arn" {
  value       = aws_autoscaling_policy.scale_out_cpu.arn
  description = "Dynamic step scale-out policy ARN"
}

output "scale_in_policy_arn" {
  value       = aws_autoscaling_policy.scale_in_cpu.arn
  description = "Dynamic step scale-in policy ARN"
}

output "cpu_high_alarm_name" {
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
  description = "CloudWatch alarm tied to scale-out"
}

output "scheduled_action_name" {
  value       = aws_autoscaling_schedule.weekday_morning_boost.scheduled_action_name
  description = "Scheduled scaling action name"
}
