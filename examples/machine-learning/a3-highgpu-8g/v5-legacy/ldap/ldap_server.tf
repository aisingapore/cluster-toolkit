# Configure the Google Cloud provider
provider "google" {
  project = "projectseald"
  region  = "us-west1"
  zone    = "us-west1-b"
}

# Set terraform backup
terraform {
  backend "gcs" {
    bucket = "proj-seald-terraform"
    prefix = "ldap-server"
  }
}

# # Create a VPC
# resource "google_compute_network" "ldap_vpc" {
#   name                    = "ldap-vpc"
#   auto_create_subnetworks = false
# }

# # Create a subnet
# resource "google_compute_subnetwork" "ldap_subnet" {
#   name          = "ldap-subnet"
#   ip_cidr_range = "172.16.0.0/24"
#   region        = "us-west1"
#   network       = google_compute_network.ldap_vpc.id
# }

# Create a firewall rule
resource "google_compute_firewall" "ldap_firewall" {
  name    = "ldap-firewall"
  network = google_compute_instance.ldap_server.network_interface[0].network

  allow {
    protocol = "tcp"
    ports    = ["22", "389", "636"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Static IP address
resource "google_compute_address" "static_ip" {
  name   = "ldap-static-ip"
  region = var.region
}

# Create a GCE instance
resource "google_compute_instance" "ldap_server" {
  name         = "ldap-server"
  machine_type = "c2-standard-4"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = "projects/projectseald/global/networks/slurm-a3-base-sysnet"
    subnetwork = "projects/projectseald/regions/us-west1/subnetworks/slurm-a3-base-sysnet-subnet"
    network_ip = "172.16.0.1"
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # metadata_startup_script = <<-EOF
  #   #!/bin/bash
  #   apt-get update
  #   apt-get install -y slapd ldap-utils
    
  #   # Additional configuration steps would go here
  # EOF

  # metadata = {
  #   ssh-keys = "username:ssh-rsa your-public-ssh-key"
  # }

  tags = ["ldap-server"]
}

# Output the public IP of the LDAP server
output "ldap_server_public_ip" {
  value = google_compute_instance.ldap_server.network_interface[0].access_config[0].nat_ip
}
