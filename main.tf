provider "google" {
  credentials = file(var.credentials_file)
  project = var.project_id
  region = var.region
}

resource "random_string" "public_bucket" {
  length  = 5
  special = false
  upper   = false
}

resource "random_string" "private_bucket" {
  length  = 5
  special = false
  upper   = false
}

resource "google_compute_disk" "index-disk-" {
  count   = var.node_count
  name    = "disk-${count.index}-data"
  zone    = var.zone
}

resource "google_compute_instance" "default" {
  count = var.node_count
  name = "${var.project_name}-${count.index}"
  machine_type = var.machine_type
  zone = var.zone

  boot_disk {
    initialize_params {
      image = var.os_image
    }
  }

  attached_disk {
    source      = element(google_compute_disk.index-disk-.*.self_link, count.index)
    device_name = element(google_compute_disk.index-disk-.*.name, count.index)
  }

  network_interface {
    network = "default"
    access_config {
    }
  }

  metadata_startup_script = "sudo yum install python;"

  metadata = {
    ssh-keys = "xtremeboost:${file(var.ssh_key_file)}"
  }

  deletion_protection  = "false"
}

resource "google_compute_instance_group" "default-instance-group" {
  name = "${var.project_name}-instance-group"

  instances = [for instance in google_compute_instance.default: instance.id]

  named_port {
    name = "http"
    port = "8080"
  }

  named_port {
    name = "https"
    port = "8443"
  }

  zone = var.zone
}


resource "google_storage_bucket" "public_bucket" {
  name = "${var.bucket_name_public}_${random_string.public_bucket.result}"
  location = var.bucket_location

  cors {
    origin = ["*"]
    method =  ["PUT","GET","DELETE","POST"]
    response_header = ["*"]
    max_age_seconds = 300
  }
}

resource "google_storage_bucket" "private_bucket" {
  name = "${var.bucket_name_private}_${random_string.private_bucket.result}"
  location = var.bucket_location
}

resource "google_storage_bucket_acl" "public_bucket" {
  bucket = google_storage_bucket.public_bucket.name

  role_entity = [
    "READER:allUsers",
  ]
}

resource "google_storage_default_object_access_control" "public_bucket" {
  bucket = google_storage_bucket.public_bucket.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_compute_firewall" "default" {
  name = "allow-http-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["80","443"]
  }

  # These IP ranges are required for health checks
  source_ranges = ["127.0.0.0/8"]
}

resource "google_sql_database_instance" "master" {
  name   = var.project_name
  database_version = var.db_version
  region = var.region
  settings {
    tier = var.db_type
    ip_configuration {
      ipv4_enabled = true
      dynamic "authorized_networks" {
        for_each = google_compute_instance.default
        iterator = default

        content {
          name  = default.value.name
          value = default.value.network_interface.0.access_config.0.nat_ip
        }
      }
    }
  }
  deletion_protection  = "true"
}

resource "google_sql_database" "database" {
  name     = var.project_name
  instance = google_sql_database_instance.master.name
}

resource "google_sql_user" "users" {
  name     = var.db_username
  instance = google_sql_database_instance.master.name
  password = var.db_password
  host = "%"
}

resource "google_service_account" "service-account" {
  account_id = "${var.project_name}-service-account"
  display_name =  "${var.project_name}-service-account"
}

resource "google_project_iam_member" "bucket_owner_binding" {
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.service-account.email}"
}