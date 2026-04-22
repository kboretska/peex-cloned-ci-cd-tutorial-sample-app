# -----------------------------------------------------------------------------
# Azure Monitor autoscale on VMSS:
# - Profile "default": two metric rules (CPU step-out / CPU step-in) = two dynamic policies.
# - Profiles "weekdays-kyiv-elevated" / "weekdays-kyiv-baseline": Mon–Fri 10:00 / 12:00 in
#   var.scheduled_timezone (default FLE Standard Time = Kyiv local) — elevated capacity 10:00–12:00 only.
#
# Azure terminology: rules inside a profile replace "scaling policies"; cooldown = scale_action.cooldown.
# -----------------------------------------------------------------------------

resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "${var.prefix}-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  # --- Always-on profile: metric-based scale-out / scale-in -----------------
  profile {
    name = "default"

    capacity {
      default = var.vmss_capacity_default
      minimum = var.vmss_capacity_min
      maximum = var.vmss_capacity_max
    }

    # Dynamic rule 1 — scale OUT when average CPU is high
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.scale_out_cpu_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Dynamic rule 2 — scale IN when average CPU is low
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.scale_in_cpu_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  # --- Scheduled window Mon–Fri 10:00–12:00 (FLE Standard Time / Kyiv): no recurrence end time in TF;
  # use two profiles — 10:00 elevated capacity, 12:00 back to baseline until next 10:00.
  profile {
    name = "weekdays-kyiv-elevated"

    recurrence {
      timezone = var.scheduled_timezone
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [10]
      minutes  = [0]
    }

    capacity {
      default = var.schedule_capacity_default
      minimum = var.vmss_capacity_min
      maximum = var.vmss_capacity_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.scale_out_cpu_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.scale_in_cpu_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  profile {
    name = "weekdays-kyiv-baseline"

    recurrence {
      timezone = var.scheduled_timezone
      days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      hours    = [12]
      minutes  = [0]
    }

    capacity {
      default = var.vmss_capacity_default
      minimum = var.vmss_capacity_min
      maximum = var.vmss_capacity_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.scale_out_cpu_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        metric_namespace   = "Microsoft.Compute/virtualMachineScaleSets"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.scale_in_cpu_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
