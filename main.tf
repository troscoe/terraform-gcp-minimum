variable "username" {
  type = string
}
variable "enrol-id" {
  type = number  
}
variable "sshpassword" {
  type = string
}
provider "google" {
  project     = "fortinet-nse-ins-1491332429129"
  region      = "us-east4"
}

data "google_compute_image" "fortipoc" {
  name = "fortidemo-nse7-lab-62"
}

data "google_service_account" "myaccount" {
  account_id = "terraform"
}

resource "google_service_account_key" "mykey" {
  service_account_id = data.google_service_account.myaccount.name
}

resource "google_compute_instance" "default" {
  name         = join("-", ["fortipoc",var.username,var.enrol-id])
  machine_type = "n1-standard-16"
  zone         = "us-east4-a"
  
  allow_stopping_for_update = true

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
      password    = var.sshpassword
    }
  }
  provisioner "local-exec" {
    command = <<EOH
curl -d '{"username":"admin","password":"${var.sshpassword}"}' -H 'Content-Type: application/json' -c cookie.txt -k https://${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}/api/v0/login
curl -d '{"poc": 1}' -H 'Content-Type: application/json' --cookie cookie.txt -k https://${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}/api/v0/poc/launch
EOH
  }
}

output "instance_ip_addr" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
