variable "subscription_id" {
  type        = string
  description = "Azure subscription GUID (Subscriptions → Overview)."
}

variable "location" {
  type        = string
  description = "Azure region. westeurope often hits B-series capacity limits; northeurope/germanywestcentral/swedencentral are common alternates."
  default     = "northeurope"
}

variable "prefix" {
  type        = string
  description = "Prefix for resource names."
  default     = "lab-vmss"
}

variable "environment" {
  type        = string
  default     = "dev"
}

variable "vm_size" {
  type        = string
  description = "VM SKU for VMSS. Default D2s_v3 — often allocates when burstable SKUs are capacity-restricted; each instance uses multiple regional vCPU cores."
  default     = "Standard_D2s_v3"
}

variable "vmss_capacity_min" {
  type        = number
  description = "Minimum VMSS instance count."
  default     = 1
}

variable "vmss_capacity_max" {
  type        = number
  description = "Maximum VMSS instance count."
  default     = 6
}

variable "vmss_capacity_default" {
  type        = number
  description = "Default/target instance count outside scheduled profile."
  default     = 2
}

variable "schedule_capacity_default" {
  type        = number
  description = "Desired capacity during scheduled weekday window (Kyiv 10:00–12:00 in autoscale.tf)."
  default     = 3
}

variable "admin_ssh_public_key" {
  type        = string
  description = "SSH public key for linux user azureuser."
  sensitive   = false
}

variable "scale_out_cpu_threshold" {
  type        = number
  description = "Percentage CPU avg — scale out above this."
  default     = 75.0
}

variable "scale_in_cpu_threshold" {
  type        = number
  description = "Percentage CPU avg — scale in below this."
  default     = 25.0
}

variable "scheduled_timezone" {
  type        = string
  description = "Azure Monitor autoscale requires a Windows timezone display name (not IANA). Kyiv → FLE Standard Time."
  default     = "FLE Standard Time"
}
