# -----------------------------------------------------------------------------
# Dynamic policy 1 — STEP scaling OUT when average CPU is high (scale-out).
# Policy type: StepScaling (adjust by fixed steps; differs from SimpleScaling &
# TargetTracking — see terraform/README-autoscaling.md).
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_out_cpu" {
  name                   = "${var.project_name}-dynamic-step-scale-out-cpu"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  metric_aggregation_type = "Average"
  estimated_instance_warmup = 180
  cooldown               = var.scaling_cooldown_seconds

  step_adjustment {
    metric_interval_lower_bound = 0
    scaling_adjustment          = 1
  }
}

# -----------------------------------------------------------------------------
# Dynamic policy 2 — STEP scaling IN when average CPU is low (scale-in).
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_in_cpu" {
  name                   = "${var.project_name}-dynamic-step-scale-in-cpu"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "StepScaling"
  metric_aggregation_type = "Average"
  estimated_instance_warmup = 180
  cooldown               = var.scaling_cooldown_seconds

  step_adjustment {
    metric_interval_upper_bound = 0
    scaling_adjustment          = -1
  }
}

# CloudWatch alarms drive the step policies using real EC2 CPU aggregated for the ASG.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high-scale-out"
  alarm_description   = "Triggers step scale-out when ASG-wide average CPU exceeds threshold for consecutive periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm   = 2
  threshold             = var.scale_out_cpu_threshold
  treat_missing_data    = "notBreaching"

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out_cpu.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low-scale-in"
  alarm_description   = "Triggers step scale-in when ASG-wide average CPU stays below threshold."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm   = 3
  threshold             = var.scale_in_cpu_threshold
  treat_missing_data    = "notBreaching"

  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  period      = 60
  statistic   = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in_cpu.arn]
}
