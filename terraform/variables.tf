variable "prefix" {
  description = "Short name used in every resource name."
  type        = string
  default     = "homelab"
}

variable "location" {
  description = "Azure region for the lab."
  type        = string
  default     = "northcentralus"
}

variable "vm_size" {
  description = "Size of each VM. Standard_B1s is the cheapest that works for this lab."
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "admin_username" {
  description = "Linux user created on each VM."
  type        = string
  default     = "labadmin"
}

variable "ssh_public_key" {
  description = "Contents of your public SSH key (~/.ssh/homelab.pub)."
  type        = string
}

variable "admin_cidr" {
  description = "Your home public IP in CIDR form, e.g. 203.0.113.5/32. Only this address can SSH in."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a CIDR like 203.0.113.5/32."
  }
}

variable "vnet_cidr" {
  description = "Address space for the lab network."
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_cidr" {
  description = "Subnet for the lab VMs. Keep it a /24 so the Ansible host pattern works."
  type        = string
  default     = "10.10.1.0/24"
}
