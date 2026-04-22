resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                = "${var.prefix}-vmss"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.vm_size
  instances           = var.vmss_capacity_default

  computer_name_prefix = "${var.prefix}vm"

  admin_username = "azureuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.admin_ssh_public_key
  }

  upgrade_mode = "Manual"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "primary"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.vmss.id
    }
  }

  custom_data = base64encode(<<-SCRIPT
    #!/bin/bash
    set -euxo pipefail
    apt-get update -y
    apt-get install -y cron stress-ng

    # 10:30 Kyiv: one stressor per logical CPU, no --cpu-load cap; use all cores.
    printf '%s\n' '#!/bin/bash' 'exec stress-ng --cpu "$(nproc)" --timeout 1800' >/usr/local/bin/stress-kyiv-cron.sh
    chmod 0755 /usr/local/bin/stress-kyiv-cron.sh

    printf '%s\n' \
      'CRON_TZ=Europe/Kyiv' \
      'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
      '' \
      '30 10 * * * root /usr/local/bin/stress-kyiv-cron.sh >> /var/log/vmss-stress-cron.log 2>&1' \
      >/etc/cron.d/vmss-stress-kyiv
    chmod 0644 /etc/cron.d/vmss-stress-kyiv
    systemctl enable --now cron

    echo "vmss-ready" > /var/tmp/bootstrap.done
  SCRIPT
  )

  tags = {
    Environment = var.environment
  }
}
