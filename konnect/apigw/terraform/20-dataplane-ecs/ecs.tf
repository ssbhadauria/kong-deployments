# ---------------------------------------------------------------------------
# OTel Collector sidecar config.
# Loaded via `--config=env:OTELCOL_CONFIG`. The distroless collector image has
# no shell, so config-from-env is the supported way to ship it in Fargate.
# `$${env:...}` is escaped so TERRAFORM leaves it for the COLLECTOR to expand
# at runtime (that's how the secret token stays out of the rendered config).
# Grafana Cloud OTLP is HTTP-only -> otlphttp exporter + basicauth extension.
# ---------------------------------------------------------------------------
locals {
  otel_config = <<-YAML
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      prometheus:
        config:
          scrape_configs:
            - job_name: kong
              scrape_interval: 15s
              metrics_path: /metrics
              static_configs:
                - targets: ["localhost:8100"]

    extensions:
      basicauth/grafana:
        client_auth:
          username: "$${env:GRAFANA_INSTANCE_ID}"
          password: "$${env:GRAFANA_OTLP_TOKEN}"

    processors:
      batch: {}
      resourcedetection:
        detectors: [env, ecs]

    exporters:
      otlphttp/grafana:
        endpoint: "$${env:GRAFANA_OTLP_ENDPOINT}"
        auth:
          authenticator: basicauth/grafana

    service:
      extensions: [basicauth/grafana]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [resourcedetection, batch]
          exporters: [otlphttp/grafana]
        metrics:
          receivers: [otlp, prometheus]
          processors: [resourcedetection, batch]
          exporters: [otlphttp/grafana]
        logs:
          receivers: [otlp]
          processors: [resourcedetection, batch]
          exporters: [otlphttp/grafana]
  YAML
}

resource "aws_cloudwatch_log_group" "dp" {
  name              = "/ecs/${var.name_prefix}-dp"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-dp"
}

resource "aws_ecs_task_definition" "dp" {
  family                   = "${var.name_prefix}-dp"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "kong"
      image     = var.kong_image
      essential = true
      portMappings = [
        { containerPort = 8000, protocol = "tcp" },
        { containerPort = 8443, protocol = "tcp" },
        { containerPort = 8100, protocol = "tcp" },
      ]
      environment = [
        { name = "KONG_ROLE", value = "data_plane" },
        { name = "KONG_DATABASE", value = "off" },
        { name = "KONG_KONNECT_MODE", value = "on" },
        { name = "KONG_VITALS", value = "off" },
        { name = "KONG_CLUSTER_MTLS", value = "pki" },
        { name = "KONG_CLUSTER_CONTROL_PLANE", value = "${local.cp_host}:443" },
        { name = "KONG_CLUSTER_SERVER_NAME", value = local.cp_host },
        { name = "KONG_CLUSTER_TELEMETRY_ENDPOINT", value = "${local.tp_host}:443" },
        { name = "KONG_CLUSTER_TELEMETRY_SERVER_NAME", value = local.tp_host },
        { name = "KONG_LUA_SSL_TRUSTED_CERTIFICATE", value = "system" },
        { name = "KONG_STATUS_LISTEN", value = "0.0.0.0:8100" },
        { name = "KONG_ADMIN_LISTEN", value = "off" },
        { name = "KONG_PROXY_LISTEN", value = "0.0.0.0:8000, 0.0.0.0:8443 ssl" },
        # Public cert passed inline (not secret); the KEY comes from ASM below.
        { name = "KONG_CLUSTER_CERT", value = tls_self_signed_cert.dp.cert_pem },
      ]
      secrets = [
        { name = "KONG_CLUSTER_CERT_KEY", valueFrom = aws_secretsmanager_secret.dp_key.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dp.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "kong"
        }
      }
    },
    {
      name      = "otel-collector"
      image     = var.otel_collector_image
      essential = false # telemetry failure must not take down the proxy
      command   = ["--config=env:OTELCOL_CONFIG"]
      portMappings = [
        { containerPort = 4317, protocol = "tcp" },
        { containerPort = 4318, protocol = "tcp" },
      ]
      environment = [
        { name = "OTELCOL_CONFIG", value = local.otel_config },
        { name = "GRAFANA_OTLP_ENDPOINT", value = var.grafana_otlp_endpoint },
        { name = "GRAFANA_INSTANCE_ID", value = var.grafana_instance_id },
      ]
      secrets = [
        { name = "GRAFANA_OTLP_TOKEN", valueFrom = aws_secretsmanager_secret.grafana_token.arn },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.dp.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "otel"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "dp" {
  name            = "${var.name_prefix}-dp"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.dp.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false # private subnets reach the internet via NAT
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = "kong"
    container_port   = 8000
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.https.arn
    container_name   = "kong"
    container_port   = 8443
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    konnect_gateway_data_plane_client_certificate.dp,
  ]
}
