# --- Security groups --------------------------------------------------------
resource "aws_security_group" "nlb" {
  name        = "${var.name_prefix}-nlb"
  description = "Internet-facing NLB for the Kong proxy"
  vpc_id      = var.vpc_id

  ingress {
    description = "Proxy HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.proxy_ingress_cidrs
  }

  ingress {
    description = "Proxy HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.proxy_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-dp-task"
  description = "Kong DP Fargate tasks"
  vpc_id      = var.vpc_id

  # Proxy ports, reachable only from inside the VPC (i.e. the NLB + health checks).
  ingress {
    description = "Kong proxy HTTP"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  ingress {
    description = "Kong proxy HTTPS"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  # Outbound to NAT: Docker Hub, Konnect CP/telemetry, Grafana Cloud OTLP.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Network Load Balancer (L4 passthrough; Kong does its own TLS/routing) ---
resource "aws_lb" "proxy" {
  name               = "${var.name_prefix}-proxy"
  load_balancer_type = "network"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.nlb.id]
}

resource "aws_lb_target_group" "http" {
  name        = "${var.name_prefix}-http"
  port        = 8000
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    protocol = "TCP"
    port     = "8000"
  }
}

resource "aws_lb_target_group" "https" {
  name        = "${var.name_prefix}-https"
  port        = 8443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    protocol = "TCP"
    port     = "8443"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.proxy.arn
  port              = 80
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.proxy.arn
  port              = 443
  protocol          = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}
