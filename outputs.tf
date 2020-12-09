output "load-balancer-ip" {
  value = google_compute_global_address.default-lb.address
}

output "sql-ip" {
  value = google_sql_database_instance.master.ip_address
}

output "google-compute-instance-ip" { 
  value = [for instance in google_compute_instance.default: instance.network_interface.0.access_config.0.nat_ip]
}