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

resource "google_compute_address" "static" {
  name = "ipv4-address"
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
      nat_ip = google_compute_address.static.address
    }
  }

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
  
  provisioner "remote-exec" {
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = "admin"
      password    = var.sshpassword
    }
  }
  provisioner "local-exec" {
    command = <<EOH
curl -H 'Content-Type: application/json' -c cookies.txt -b cookies.txt -k https://${google_compute_address.static.address}/api/v0/login -d '{"username":"admin","password":"${var.sshpassword}"}'
srftoken=`grep csrftoken cookies.txt | cut -f 7`
sleep 10
curl -H "X-Fortipoc-Csrftoken: $srftoken" -H 'Content-Type: application/json' -c cookies.txt -b cookies.txt -e https://${google_compute_address.static.address} -k https://${google_compute_address.static.address}/api/v0/poc/launch -d '{"poc":"1"}'
EOH
  }
}

resource "null_resource" "start_instance" {
  provisioner "local-exec" {
    command     = <<EOH
export PATH="/terraform/google-cloud-sdk/bin:$PATH"
wget https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-283.0.0-linux-x86_64.tar.gz
tar -xf google-cloud-sdk-283.0.0-linux-x86_64.tar.gz
cd google-cloud-sdk
./install.sh
cat >> /terraform/google-cloud-sdk/key.json <<EOL
${base64decode(google_service_account_key.mykey.private_key)}
EOL
gcloud auth activate-service-account --key-file=/terraform/google-cloud-sdk/key.json
gcloud compute instances start ${google_compute_instance.default.name} --zone ${google_compute_instance.default.zone}
EOH
  }
  
  provisioner "remote-exec" {
    connection {
      host        = google_compute_address.static.address
      type        = "ssh"
      user        = "admin"
      password    = var.sshpassword
    }
  }
  
  provisioner "local-exec" {
    command = <<EOH
curl -H 'Content-Type: application/json' -c cookies.txt -b cookies.txt -k https://${google_compute_address.static.address}/api/v0/login -d '{"username":"admin","password":"${var.sshpassword}"}'
srftoken=`grep csrftoken cookies.txt | cut -f 7`
sleep 10
curl -H "X-Fortipoc-Csrftoken: $srftoken" -H 'Content-Type: application/json' -c cookies.txt -b cookies.txt -e https://${google_compute_address.static.address} -k https://${google_compute_address.static.address}/api/v0/poc/current/devices/poweron -d '{"devices":[1,2,3,4,5,6,7,8,9,10,11]}'
EOH
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

output "instance_ip_addr" {
  value = google_compute_address.static.address
}
