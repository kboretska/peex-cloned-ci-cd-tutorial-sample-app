variable "aws_region" {
  type        = string
  description = "AWS region for all resources."
  default     = "eu-central-1"
}

variable "project_name" {
  type        = string
  description = "Prefix for resource names."
  default     = "lab-asg"
}

variable "environment" {
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.42.0.0/16"
}

variable "instance_type" {
  type        = string
  description = "Use free-tier friendly size for labs (e.g. t3.micro, t2.micro where available)."
  default     = "t3.micro"
}

variable "asg_min_size" {
  type        = number
  description = "Minimum instances in the ASG."
  default     = 1
}

variable "asg_max_size" {
  type        = number
  description = "Maximum instances in the ASG."
  default     = 4
}

variable "asg_desired_capacity" {
  type        = number
  description = "Desired capacity at steady state."
  default     = 2
}

variable "scale_out_cpu_threshold" {
  type        = number
  description = "Average CPU %% across the ASG to trigger scale-out (step policy 1)."
  default     = 65.0
}

variable "scale_in_cpu_threshold" {
  type        = number
  description = "Average CPU %% across the ASG to trigger scale-in (step policy 2)."
  default     = 25.0
}

variable "scaling_cooldown_seconds" {
  type        = number
  description = "Cooldown between scaling activities (same as AWS console 'cooldown')."
  default     = 300
}

variable "scheduled_desired_capacity" {
  type        = number
  description = "Desired capacity during scheduled 'business hours' window."
  default     = 3
}

variable "scheduled_recurrence_cron" {
  type        = string
  description = "Cron for scheduled scale-up (UTC). Example: weekdays 07:00 UTC."
  default     = "0 7 * * MON-FRI"
}

variable "scheduled_scale_in_recurrence_cron" {
  type        = string
  description = "Cron for scheduled return to baseline (UTC). Example: weekdays 18:00 UTC."
  default     = "0 18 * * MON-FRI"
}
