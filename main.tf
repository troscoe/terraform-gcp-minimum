variable "username" {
  type = string
}
variable "enrol-id" {
  type = number  
}
provider "google" {
  project     = "fortinet-nse-ins-1491332429129"
  region      = "us-east4"
}

data "google_compute_image" "fortipoc" {
  name = "fortipoc"
}

resource "google_compute_instance" "default" {
  name         = join("-", ["fortipoc",var.username,var.enrol-id])
  machine_type = "n1-standard-2"
  zone         = "us-east4-a"

  tags = ["http-server", "https-server"]

  boot_disk {
    initialize_params {
      size  = 400
      type  = "pd-standard"
      image = data.google_compute_image.fortipoc.self_link
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}

output "instance_ip_addr" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
