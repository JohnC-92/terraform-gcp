// Reference:
// https://binx.io/blog/2018/11/19/how-to-configure-global-load-balancing-with-google-cloud-platform/

// Reserve an public/external internet address
resource "google_compute_global_address" "default-lb" {
  name = var.project_name
  address_type = "EXTERNAL" 
}

// ----------------------------------- HTTPS Load Balancer Settings -----------------------------------
// Global forwarding rule to forward traffic directed at port 443 of created ip address to target our HTTPS proxy
resource "google_compute_global_forwarding_rule" "default-https-forward-rule" {
  name = "${var.project_name}-port-443"
  ip_address = google_compute_global_address.default-lb.address
  port_range = "443"
  target = google_compute_target_https_proxy.default-https.id
}

// Target https proxy uses URL map to send traffic to backend
resource "google_compute_target_https_proxy" "default-https" {
  name = var.project_name
  url_map = google_compute_url_map.default-https.id
  ssl_certificates = [google_compute_ssl_certificate.default-https.id]
}

resource "google_compute_ssl_certificate" "default-https" {
  name        = "${var.project_name}-certificate"
  private_key = file(var.https_private_key)
  certificate = file(var.https_certificate)
}

resource "google_compute_url_map" "default-https" {
  name = "${var.project_name}-https"
  default_service = google_compute_backend_service.default-https-lb.id
}

// Backend service consists of one or more instance group which are possible destinations for traffic from target proxy
resource "google_compute_backend_service" "default-https-lb" {
  name = "${var.project_name}-https-backend-service"
  protocol = "HTTPS"
  port_name = var.project_name
  timeout_sec = 30
  backend {
    group = google_compute_instance_group.default-instance-group.id
  }

  health_checks= [google_compute_health_check.https-health-check.id]
}

// Health checks are used by the load balancer to determine which instance can handle traffic
resource "google_compute_health_check" "https-health-check" {
  name = "https-health-check"

  timeout_sec        = 5
  check_interval_sec = 10

  https_health_check {
    # request_path = "/"
    port = 443
  }
}

// ----------------------------------- HTTP Load Balancer Settings -----------------------------------
// Global forwarding rule to forward traffic directed at port 80 of created ip address to target our HTTP proxy
resource "google_compute_global_forwarding_rule" "default-http-forward-rule" {
  name = "${var.project_name}-port-80"
  ip_address = google_compute_global_address.default-lb.address
  port_range = "80"
  target = google_compute_target_http_proxy.default-http.id
}

// Target http proxy uses URL map to redirect traffic to https route
resource "google_compute_target_http_proxy" "default-http" {
  name = var.project_name
  url_map = google_compute_url_map.default-http.id
}

resource "google_compute_url_map" "default-http" {
  name = "${var.project_name}-http"
  
  // no default service here (no backend service, no backend bucket)
  // only redirection to https

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

