resource "aws_autoscaling_group" "main" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = aws_subnet.public[*].id
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size = var.asg_min_size
  max_size = var.asg_max_size

  desired_capacity      = var.asg_desired_capacity
  default_cooldown      = var.scaling_cooldown_seconds
  protect_from_scale_in = false
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-member"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
