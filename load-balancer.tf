// Reference:
// https://binx.io/blog/2018/11/19/how-to-configure-global-load-balancing-with-google-cloud-platform/

// Reserve an public/external internet address
resource "google_compute_global_address" "default-lb" {
  name = var.project_name
  address_type = "EXTERNAL" 
}

// Global forwarding rule to forward traffic directed at port 80 of created ip address to target our HTTP proxy
resource "google_compute_global_forwarding_rule" "default-forward-rule" {
  name = "${var.project_name}-port-80"
  ip_address = google_compute_global_address.default-lb.address
  port_range = "80"
  target = google_compute_target_http_proxy.default.id
}

// Target http proxy uses URL map to send traffic to backend
resource "google_compute_target_http_proxy" "default" {
  name = var.project_name
  url_map = google_compute_url_map.default.id
}

resource "google_compute_url_map" "default" {
  name = var.project_name
  default_service = google_compute_backend_service.default.id
}

// Backend service consists of one or more instance group which are possible destinations for traffic from target proxy
resource "google_compute_backend_service" "default" {
  name = "${var.project_name}-backend-service"
  protocol = "HTTP"
  port_name = var.project_name
  timeout_sec = 10
  backend {
    group = google_compute_instance_group.default-instance-group.id
  }

  health_checks= [google_compute_health_check.http-health-check.id]
}

// Health checks are used by the load balancer to determine which instance can handle traffic
resource "google_compute_health_check" "http-health-check" {
  name = "http-health-check"

  timeout_sec        = 5
  check_interval_sec = 5

  http_health_check {
    # request_path = "/"
    port = 80
  }
}