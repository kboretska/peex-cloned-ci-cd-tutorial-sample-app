resource "aws_security_group" "asg" {
  name        = "${var.project_name}-asg-sg"
  description = "Lab ASG instances - SSH optional, outbound all"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH (restrict source in production)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-asg-sg"
  }
}
