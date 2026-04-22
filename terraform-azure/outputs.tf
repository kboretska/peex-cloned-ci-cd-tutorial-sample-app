output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource group name"
}

output "vmss_name" {
  value       = azurerm_linux_virtual_machine_scale_set.main.name
  description = "VM Scale Set name — check Instances + autoscale in portal"
}

output "vmss_id" {
  value       = azurerm_linux_virtual_machine_scale_set.main.id
  description = "VMSS resource ID (target of autoscale setting)"
}

output "autoscale_setting_name" {
  value       = azurerm_monitor_autoscale_setting.vmss.name
  description = "Azure Monitor autoscale setting name"
}
