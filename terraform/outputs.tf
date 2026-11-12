output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "nsg_name" {
  value = azurerm_network_security_group.lab.name
}

output "web_public_ip" {
  value = azurerm_public_ip.vm["web"].ip_address
}

output "db_public_ip" {
  value = azurerm_public_ip.vm["db"].ip_address
}

output "db_private_ip" {
  description = "Enter this as the database host in the WordPress setup page."
  value       = azurerm_network_interface.vm["db"].private_ip_address
}

output "blog_url" {
  value = "http://${azurerm_public_ip.vm["web"].ip_address}"
}

output "ssh_web" {
  value = "ssh -i ~/.ssh/homelab ${var.admin_username}@${azurerm_public_ip.vm["web"].ip_address}"
}

output "ssh_db" {
  value = "ssh -i ~/.ssh/homelab ${var.admin_username}@${azurerm_public_ip.vm["db"].ip_address}"
}
