# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "name" {
  description = <<-EOD
    Name of the nodeset. Automatically populated by the module id if not set.
    If setting manually, ensure a unique value across all nodesets.
    EOD
  type        = string
}

variable "project_id" {
  type        = string
  description = "Project ID to create resources in."
}

variable "node_conf" {
  description = "Map of Slurm node line configuration."
  type        = map(any)
  default     = {}
}

variable "node_count_static" {
  description = "Number of nodes to be statically created."
  type        = number
  default     = 0
}

variable "node_count_dynamic_max" {
  description = "Maximum number of auto-scaling nodes allowed in this partition."
  type        = number
  default     = 10
}

## VM Definition
variable "instance_template" { # tflint-ignore: terraform_unused_declarations
  description = "DEPRECATED: Instance template can not be specified for compute nodes."
  type        = string
  default     = null
  validation {
    condition     = var.instance_template == null
    error_message = "DEPRECATED: Instance template can not be specified for compute nodes."
  }
}

variable "machine_type" {
  description = "Compute Platform machine type to use for this partition compute nodes."
  type        = string
  default     = "c2-standard-60"
}

variable "metadata" {
  type        = map(string)
  description = "Metadata, provided as a map."
  default     = {}
}

variable "instance_image" {
  description = <<-EOD
    Defines the image that will be used in the Slurm node group VM instances.

    Expected Fields:
    name: The name of the image. Mutually exclusive with family.
    family: The image family to use. Mutually exclusive with name.
    project: The project where the image is hosted.

    For more information on creating custom images that comply with Slurm on GCP
    see the "Slurm on GCP Custom Images" section in docs/vm-images.md.
    EOD
  type        = map(string)
  default = {
    family  = "slurm-gcp-6-5-hpc-rocky-linux-8"
    project = "schedmd-slurm-public"
  }

  validation {
    condition     = can(coalesce(var.instance_image.project))
    error_message = "In var.instance_image, the \"project\" field must be a string set to the Cloud project ID."
  }

  validation {
    condition     = can(coalesce(var.instance_image.name)) != can(coalesce(var.instance_image.family))
    error_message = "In var.instance_image, exactly one of \"family\" or \"name\" fields must be set to desired image family or name."
  }
}

variable "instance_image_custom" {
  description = <<-EOD
    A flag that designates that the user is aware that they are requesting
    to use a custom and potentially incompatible image for this Slurm on
    GCP module.

    If the field is set to false, only the compatible families and project
    names will be accepted.  The deployment will fail with any other image
    family or name.  If set to true, no checks will be done.

    See: https://goo.gle/hpc-slurm-images
    EOD
  type        = bool
  default     = false
}

variable "tags" {
  type        = list(string)
  description = "Network tag list."
  default     = []
}

variable "disk_type" {
  description = "Boot disk type, can be either hyperdisk-balanced, pd-ssd, pd-standard, pd-balanced, or pd-extreme."
  type        = string
  default     = "pd-standard"
}

variable "disk_size_gb" {
  description = "Size of boot disk to create for the partition compute nodes."
  type        = number
  default     = 50
}

variable "disk_auto_delete" {
  type        = bool
  description = "Whether or not the boot disk should be auto-deleted."
  default     = true
}

variable "disk_labels" {
  description = "Labels specific to the boot disk. These will be merged with var.labels."
  type        = map(string)
  default     = {}
}

variable "additional_disks" {
  description = "Configurations of additional disks to be included on the partition nodes. (do not use \"disk_type: local-ssd\"; known issue being addressed)"
  type = list(object({
    disk_name    = string
    device_name  = string
    disk_size_gb = number
    disk_type    = string
    disk_labels  = map(string)
    auto_delete  = bool
    boot         = bool
  }))
  default = []
}

variable "enable_confidential_vm" {
  type        = bool
  description = "Enable the Confidential VM configuration. Note: the instance image must support option."
  default     = false
}

variable "enable_shielded_vm" {
  type        = bool
  description = "Enable the Shielded VM configuration. Note: the instance image must support option."
  default     = false
}

variable "shielded_instance_config" {
  type = object({
    enable_integrity_monitoring = bool
    enable_secure_boot          = bool
    enable_vtpm                 = bool
  })
  description = <<-EOD
    Shielded VM configuration for the instance. Note: not used unless
    enable_shielded_vm is 'true'.
    - enable_integrity_monitoring : Compare the most recent boot measurements to the
      integrity policy baseline and return a pair of pass/fail results depending on
      whether they match or not.
    - enable_secure_boot : Verify the digital signature of all boot components, and
      halt the boot process if signature verification fails.
    - enable_vtpm : Use a virtualized trusted platform module, which is a
      specialized computer chip you can use to encrypt objects like keys and
      certificates.
    EOD
  default = {
    enable_integrity_monitoring = true
    enable_secure_boot          = true
    enable_vtpm                 = true
  }
}


variable "enable_oslogin" {
  type        = bool
  description = <<-EOD
    Enables Google Cloud os-login for user login and authentication for VMs.
    See https://cloud.google.com/compute/docs/oslogin
    EOD
  default     = true
}

variable "can_ip_forward" {
  description = "Enable IP forwarding, for NAT instances for example."
  type        = bool
  default     = false
}

variable "enable_smt" {
  type        = bool
  description = "Enables Simultaneous Multi-Threading (SMT) on instance."
  default     = false
}

variable "labels" {
  description = "Labels to add to partition compute instances. Key-value pairs."
  type        = map(string)
  default     = {}
}

variable "min_cpu_platform" {
  description = "The name of the minimum CPU platform that you want the instance to use."
  type        = string
  default     = null
}

variable "on_host_maintenance" {
  type        = string
  description = <<-EOD
    Instance availability Policy.

    Note: Placement groups are not supported when on_host_maintenance is set to
    "MIGRATE" and will be deactivated regardless of the value of
    enable_placement. To support enable_placement, ensure on_host_maintenance is
    set to "TERMINATE".
    EOD
  default     = "TERMINATE"
}

variable "guest_accelerator" {
  description = "List of the type and count of accelerator cards attached to the instance."
  type = list(object({
    type  = string,
    count = number
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(var.guest_accelerator) <= 1
    error_message = "The Slurm modules supports 0 or 1 models of accelerator card on each node."
  }
}

variable "preemptible" {
  description = "Should use preemptibles to burst."
  type        = bool
  default     = false
}


variable "service_account_email" {
  description = "Service account e-mail address to attach to the compute instances."
  type        = string
  default     = null
}

variable "service_account_scopes" {
  description = "Scopes to attach to the compute instances."
  type        = set(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "service_account" { # tflint-ignore: terraform_unused_declarations
  description = "DEPRECATED: Use `service_account_email` and `service_account_scopes` instead."
  type = object({
    email  = string
    scopes = set(string)
  })
  default = null
  validation {
    condition     = var.service_account == null
    error_message = "DEPRECATED: Use `service_account_email` and `service_account_scopes` instead."
  }
}

variable "enable_spot_vm" {
  description = "Enable the partition to use spot VMs (https://cloud.google.com/spot-vms)."
  type        = bool
  default     = false
}

variable "spot_instance_config" {
  description = "Configuration for spot VMs."
  type = object({
    termination_action = string
  })
  default = null
}

variable "bandwidth_tier" {
  description = <<EOT
  Configures the network interface card and the maximum egress bandwidth for VMs.
  - Setting `platform_default` respects the Google Cloud Platform API default values for networking.
  - Setting `virtio_enabled` explicitly selects the VirtioNet network adapter.
  - Setting `gvnic_enabled` selects the gVNIC network adapter (without Tier 1 high bandwidth).
  - Setting `tier_1_enabled` selects both the gVNIC adapter and Tier 1 high bandwidth networking.
  - Note: both gVNIC and Tier 1 networking require a VM image with gVNIC support as well as specific VM families and shapes.
  - See [official docs](https://cloud.google.com/compute/docs/networking/configure-vm-with-high-bandwidth-configuration) for more details.
  EOT
  type        = string
  default     = "platform_default"

  validation {
    condition     = contains(["platform_default", "virtio_enabled", "gvnic_enabled", "tier_1_enabled"], var.bandwidth_tier)
    error_message = "Allowed values for bandwidth_tier are 'platform_default', 'virtio_enabled', 'gvnic_enabled', or 'tier_1_enabled'."
  }
}

variable "enable_public_ips" {
  description = "If set to true. The node group VMs will have a random public IP assigned to it. Ignored if access_config is set."
  type        = bool
  default     = false
}

variable "disable_public_ips" { # tflint-ignore: terraform_unused_declarations
  description = "DEPRECATED: Use `enable_public_ips` instead."
  type        = bool
  default     = null
  validation {
    condition     = var.disable_public_ips == null
    error_message = "DEPRECATED: Use `enable_public_ips` instead."
  }
}


variable "enable_placement" {
  description = "Enable placement groups."
  type        = bool
  default     = true
}

variable "region" {
  description = "The default region for Cloud resources."
  type        = string
}


variable "zone" {
  description = "Zone in which to create compute VMs. Additional zones in the same region can be specified in var.zones."
  type        = string
}

variable "zones" {
  description = <<-EOD
    Additional zones in which to allow creation of partition nodes. Google Cloud
    will find zone based on availability, quota and reservations.
    Should not be set if SPECIFIC reservation is used.
    EOD
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for x in var.zones : length(regexall("^[a-z]+-[a-z]+[0-9]-[a-z]$", x)) > 0
    ])
    error_message = "A value in var.zones is not a valid zone (example: us-central1-f)."
  }
}

variable "zone_target_shape" {
  description = <<EOD
Strategy for distributing VMs across zones in a region.
ANY
  GCE picks zones for creating VM instances to fulfill the requested number of VMs
  within present resource constraints and to maximize utilization of unused zonal
  reservations.
ANY_SINGLE_ZONE (default)
  GCE always selects a single zone for all the VMs, optimizing for resource quotas,
  available reservations and general capacity.
BALANCED
  GCE prioritizes acquisition of resources, scheduling VMs in zones where resources
  are available while distributing VMs as evenly as possible across allowed zones
  to minimize the impact of zonal failure.
EOD
  type        = string
  default     = "ANY_SINGLE_ZONE"
  validation {
    condition     = contains(["ANY", "ANY_SINGLE_ZONE", "BALANCED"], var.zone_target_shape)
    error_message = "Allowed values for zone_target_shape are \"ANY\", \"ANY_SINGLE_ZONE\", or \"BALANCED\"."
  }
}

variable "subnetwork_self_link" {
  type        = string
  description = "Subnet to deploy to."
}

variable "additional_networks" {
  description = "Additional network interface details for GCE, if any."
  default     = []
  type = list(object({
    network            = string
    subnetwork         = string
    subnetwork_project = string
    network_ip         = string
    nic_type           = string
    stack_type         = string
    queue_count        = number
    access_config = list(object({
      nat_ip       = string
      network_tier = string
    }))
    ipv6_access_config = list(object({
      network_tier = string
    }))
    alias_ip_range = list(object({
      ip_cidr_range         = string
      subnetwork_range_name = string
    }))
  }))
}

variable "access_config" {
  description = "Access configurations, i.e. IPs via which the VM instance can be accessed via the Internet."
  type = list(object({
    nat_ip       = string
    network_tier = string
  }))
  default = []
}

variable "reservation_name" {
  description = <<-EOD
    Name of the reservation to use for VM resources, should be in one of the following formats:
    - projects/PROJECT_ID/reservations/RESERVATION_NAME
    - RESERVATION_NAME

    Must be a "SPECIFIC" reservation
    Set to empty string if using no reservation or automatically-consumed reservations
  EOD
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.reservation_name == "" || length(regexall("^projects/[a-z0-9-]+/reservations/[a-z0-9-]+$", var.reservation_name)) > 0 || length(regexall("^[a-z0-9-]+$", var.reservation_name)) > 0
    error_message = "Reservation name must be in the format 'projects/PROJECT_ID/reservations/RESERVATION_NAME' or 'RESERVATION_NAME'."
  }
}

variable "maintenance_interval" {
  description = <<-EOD
    Sets the maintenance interval for instances in this nodeset.
    See https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance#maintenance_interval.
  EOD
  type        = string
  default     = null
}

variable "startup_script" {
  description = <<-EOD
    Startup script used by VMs in this nodeset.
    NOTE: will be executed after `compute_startup_script` defined on controller module.
  EOD
  type        = string
  default     = "# no-op"
}

variable "network_storage" {
  description = "An array of network attached storage mounts to be configured on nodes."
  type = list(object({
    server_ip     = string,
    remote_mount  = string,
    local_mount   = string,
    fs_type       = string,
    mount_options = string,
  }))
  default = []
}
