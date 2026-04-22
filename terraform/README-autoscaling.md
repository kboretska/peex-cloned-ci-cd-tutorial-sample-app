# Terraform — EC2 Auto Scaling (lab)

This stack satisfies a typical **VM autoscaling** assignment:

| Requirement | Implementation |
|-------------|----------------|
| Launch template | `aws_launch_template.app` |
| ASG min/max | `aws_autoscaling_group.main` (`min_size`, `max_size`, `desired_capacity`) |
| ≥2 dynamic policies | **StepScaling** scale-out + **StepScaling** scale-in (`scaling_policies.tf`) |
| Metric-driven | CloudWatch alarms on **`AWS/EC2` `CPUUtilization`** with dimension **`AutoScalingGroupName`** |
| Scheduled action | `aws_autoscaling_schedule.weekday_morning_boost` |
| Cooldown | `default_cooldown` on ASG + `cooldown` on policies |
| Health checks | `health_check_type = "EC2"` + grace period |

## Policy types (documentation)

| Type | Behaviour |
|------|-----------|
| **SimpleScaling** | Single adjustment per alarm breach; waits full cooldown between activities (older pattern). |
| **StepScaling** | Multiple **step adjustments** based on breach magnitude; still respects cooldown after each activity. Used here for CPU high/low. |
| **TargetTrackingScaling** | Keeps a metric near a **target** (e.g. 50% CPU) — AWS adds/removes capacity continuously; not used in this minimal lab so we can show two explicit **step** policies. |

## Prerequisites

- AWS CLI configured (`aws configure`) or environment variables / IAM role with rights for VPC, EC2, Auto Scaling, CloudWatch.
- Terraform ≥ 1.3.

## Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Metric thresholds (defaults)

| Variable | Default | Meaning |
|----------|---------|---------|
| `scale_out_cpu_threshold` | `65` | Average CPU % → scale **out** (+1 instance per policy step) |
| `scale_in_cpu_threshold` | `25` | Average CPU % → scale **in** (-1) |
| `scaling_cooldown_seconds` | `300` | Pause between scaling activities |

Override with a `terraform.tfvars` file (not committed) or `-var` flags.

## How to trigger scaling (real load — no placeholders)

1. Get instance IDs from the ASG (Console → EC2 → Auto Scaling Groups → instances, or AWS CLI).
2. SSM Session Manager or SSH to a public instance (security group allows SSH from `0.0.0.0/0` — **tighten for production**).
3. Install/use CPU stress (user data already installs `stress-ng` when available):

   ```bash
   stress-ng --cpu 2 --timeout 600s
   ```

4. Watch **CloudWatch → Alarms** and **EC2 → Auto Scaling Groups → Activity** for scale-out; stop stress and wait for scale-in when average CPU drops.

If alarms stay **INSUFFICIENT_DATA**, wait a few minutes after instances launch, confirm standard EC2 CPU metrics in CloudWatch, and verify the ASG name in alarm dimensions matches your group.

## Scheduled action

- Default cron: **`0 7 * * MON-FRI`** UTC — sets `desired_capacity` to `scheduled_desired_capacity` (default `3`).
- Adjust `scheduled_recurrence_cron` / `scheduled_desired_capacity` in `variables.tf` or tfvars.

## Destroy

```bash
terraform destroy
```

## Cost notes

- Uses small instance type (`t3.micro` by default) and bounded `max_size`.
- NAT Gateway is **not** deployed (public subnets only) to reduce cost.

## Screenshots for coursework

Capture from AWS Console:

1. Launch template version details.
2. ASG **Min / Desired / Max** and **Automatic scaling** policies & alarms.
3. Scheduled actions tab.
4. CloudWatch alarm history + ASG **Activity** during stress test.
5. EC2 instance count before/after.
