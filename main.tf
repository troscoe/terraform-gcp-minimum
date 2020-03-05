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
      bzr checkout --lightweight bzr://bzr.savannah.gnu.org/gsrc/trunk/ gsrc
      cd gsrc/
      ./bootstrap
      ./configure --prefix=$HOME/gnu
      . ./setup.sh
      install gsrc
      cd ..
      wget http://sourceforge.net/projects/sshpass/files/latest/download -O sshpass.tar.gz
      tar -xvf sshpass.tar.gz
      ls
      cd sshpass-1.06
      ./configure --prefix=$HOME
      make
      make install
      sshpass -p ${var.sshpassword} ssh admin@${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}
      ssh admin@${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}
      poc launch 1
      EOH
  }
}

output "instance_ip_addr" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}
