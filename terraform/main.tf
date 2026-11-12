locals {
  # Two VMs: one runs the website, one runs the database.
  # Adding a third server is as easy as adding a line here.
  vms = {
    web = { role = "web" }
    db  = { role = "database" }
  }

  tags = {
    project    = var.prefix
    managed_by = "terraform"
  }

  # "10.10.1.0/24" -> "10.10.1.%" so MySQL accepts connections from the lab subnet only.
  subnet_pattern = format("%s.%%", join(".", slice(split(".", cidrhost(var.subnet_cidr, 0)), 0, 3)))
}

# ---------- Resource group: a folder for everything in the lab ----------

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags
}

# ---------- Network ----------

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.prefix}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_subnet" "lab" {
  name                 = "snet-lab"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = [var.subnet_cidr]
}

# Firewall rules for the whole subnet.
# Traffic between the two VMs (web -> MySQL on 3306) is allowed by Azure's
# built-in "AllowVnetInBound" rule, so it doesn't need a rule here.
resource "azurerm_network_security_group" "lab" {
  name                = "nsg-${var.prefix}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh-from-admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Only exists during a deploy: lets the GitHub runner SSH in, then is removed.
  dynamic "security_rule" {
    for_each = var.ci_runner_cidr == "" ? [] : [var.ci_runner_cidr]
    content {
      name                       = "allow-ssh-from-ci-runner"
      priority                   = 150
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "lab" {
  subnet_id                 = azurerm_subnet.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

# ---------- One public IP, network card, and VM per entry in local.vms ----------

resource "azurerm_public_ip" "vm" {
  for_each = local.vms

  name                = "pip-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "vm" {
  for_each = local.vms

  name                = "nic-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm[each.key].id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = local.vms

  name                  = "vm-${var.prefix}-${each.key}"
  resource_group_name   = azurerm_resource_group.lab.name
  location              = azurerm_resource_group.lab.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm[each.key].id]
  tags                  = merge(local.tags, { role = each.value.role })

  # SSH key only. Password login is disabled by default.
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ---------- Hand-off to Ansible ----------
# Terraform writes the Ansible inventory, so Ansible always knows the real IPs.

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.tftpl", {
    web_ip         = azurerm_public_ip.vm["web"].ip_address
    db_ip          = azurerm_public_ip.vm["db"].ip_address
    db_private_ip  = azurerm_network_interface.vm["db"].private_ip_address
    admin_username = var.admin_username
    subnet_pattern = local.subnet_pattern
  })
}
