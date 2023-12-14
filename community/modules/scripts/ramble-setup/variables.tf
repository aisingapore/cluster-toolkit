/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

variable "project_id" {
  description = "Project in which the HPC deployment will be created."
  type        = string
}

variable "install_dir" {
  description = "Destination directory of installation of Ramble."
  default     = "/apps/ramble"
  type        = string
}

variable "ramble_url" {
  description = "URL for Ramble repository to clone."
  default     = "https://github.com/GoogleCloudPlatform/ramble"
  type        = string
}

variable "ramble_ref" {
  description = "Git ref to checkout for Ramble."
  default     = "develop"
  type        = string
}

variable "chown_owner" {
  description = "Owner to chown the Ramble clone to. Default will not modify the clone."
  default     = null
  type        = string
}

variable "chgrp_group" {
  description = "Group to chgrp the Ramble clone to. Default will not modify the clone."
  default     = null
  type        = string
}

variable "chmod_mode" {
  description = <<-EOT
    Mode to chmod the Ramble clone to. Defaults to null (i.e. do not modify).
    For usage information see:
    https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html#parameter-mode
    EOT
  default     = null
  type        = string
}

variable "ramble_virtualenv_path" {
  description = "Virtual environment path in which to install Ramble Python interpreter and other dependencies"
  default     = "/usr/local/ramble-python"
  type        = string
}

variable "deployment_name" {
  description = "Name of deployment, used to name bucket containing startup script."
  type        = string
}

variable "region" {
  description = "Region to place bucket containing startup script."
  type        = string
}

variable "labels" {
  description = "Key-value pairs of labels to be added to created resources."
  type        = map(string)
}

variable "ramble_profile_script_path" {
  description = "Path to the Ramble profile.d script. Created by this module"
  type        = string
  default     = "/etc/profile.d/ramble.sh"
}