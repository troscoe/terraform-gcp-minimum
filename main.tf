variable "email" {
  type = string
}

variable "password" {
  type = string
}

provider "google" {
  project     = "fortinet-nse-ins-1491332429129"
  region      = "us-east4"
}

data "google_compute_image" "fortipoc" {
  name = "fortipoc"
}

resource "google_compute_instance" "default" {
  name         = "fortipoc-troscoe"
  machine_type = "n1-standard-4"
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

  provisioner "remote-exec" {
    connection {
      host        = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
      type        = "ssh"
      user        = "admin"
    }
  }
  provisioner "local-exec" {
    command = <<EOH
ssh admin@${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}
register FNDN ${var.email}
${var.password}
EOH
  }
}
