# -----------------------------------------------------------------------------
# Scheduled scaling — recurring capacity bump during weekday mornings (UTC).
# Adjust recurrence / time_zone to match your "business hours" lab definition.
# -----------------------------------------------------------------------------
resource "aws_autoscaling_schedule" "weekday_morning_boost" {
  scheduled_action_name  = "${var.project_name}-scheduled-weekday-morning"
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.scheduled_desired_capacity
  recurrence             = var.scheduled_recurrence_cron
  time_zone              = "UTC"
  autoscaling_group_name = aws_autoscaling_group.main.name
}
