resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.asg.id]

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf install -y stress-ng || true
    echo "lab-asg-ready" > /var/tmp/bootstrap.done
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
