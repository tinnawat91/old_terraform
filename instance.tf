# resource group
resource "azurerm_resource_group" "ResourceGroup" {
    name = "AMS_Teams"
    location = "Southeast Asia"

    # lifecycle {
    #     prevent_destroy = true
    # }
}

# # #virtual network
# # resource "azurerm_virtual_network" "VirtualNetwork" {
# #     name = "terraform_Vnet"
# #     address_space = [ "10.0.0.0/16" ]
# #     location = azurerm_resource_group.ResourceGroup.location
# #     resource_group_name = azurerm_resource_group.ResourceGroup.name

# #     tags = {
# #         "terraform" = "rabbitmq"
# #     }
# # }

# # # subnet
# # resource "azurerm_subnet" "Subnet" {
# #     name = "terraform_subnet"
# #     resource_group_name = azurerm_resource_group.ResourceGroup.name
# #     virtual_network_name = azurerm_virtual_network.VirtualNetwork.name
# #     address_prefixes = [ "10.0.1.0/24" ]
# # }

# get virtual network
data "azurerm_virtual_network" "GetVnet" {
    name = "AMS_Teams-vnet"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
}

# get subnet
data "azurerm_subnet" "GetSubnet" {
    name = "default"
    virtual_network_name = data.azurerm_virtual_network.GetVnet.name
    resource_group_name = azurerm_resource_group.ResourceGroup.name
}

# public IPs
resource "azurerm_public_ip" "PublicIP" {
    count = var.vm_count
    name = "${var.resource_prefix}_publicIP_${count.index + 1}"
    location = azurerm_resource_group.ResourceGroup.location
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    allocation_method = "Dynamic"
    tags = {
        "terraform" = "rabbitmq"
    }
}

# network security group
resource "azurerm_network_security_group" "NetworkSecurityGroup" {
    name = "${var.resource_prefix}_network_security_group"
    location = azurerm_resource_group.ResourceGroup.location
    resource_group_name = azurerm_resource_group.ResourceGroup.name

    security_rule {
        access = "Allow"
        destination_address_prefix = "*"
        destination_port_range = "22"
        direction = "Inbound"
        name = "SSH"
        priority = 300
        protocol = "TCP"
        source_address_prefix = "*"
        source_port_range = "*"
    }
    

    tags = {
        "terraform" = "rabbitmq"
    }
}

# load balancer
resource "azurerm_lb" "LoadBalancer" {
    name = "${var.resource_prefix}_rebbitmq_lb"
    location = azurerm_resource_group.ResourceGroup.location
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    sku = "Standard"
    frontend_ip_configuration {
        name = "${lookup(var.FrontEndIP.0, "name")}"
        subnet_id = data.azurerm_subnet.GetSubnet.id
        private_ip_address_allocation = "Dynamic"
    }

    frontend_ip_configuration {
        name = "${lookup(var.FrontEndIP.1, "name")}"
        subnet_id = data.azurerm_subnet.GetSubnet.id
        private_ip_address_allocation = "Dynamic"
    }

    tags = {
        "terraform" = "rabbitmq"
    }
}

# load balancer backend pool
resource "azurerm_lb_backend_address_pool" "LoadBalancerBackEndPool" {
    # count = var.vm_count
    # name = "terraform_rabbitmq_backend_pool_${count.index + 1}"
    name = "${var.resource_prefix}_rabbitmq_backend_pool"
    loadbalancer_id = azurerm_lb.LoadBalancer.id
}

# load balancer health probe
resource "azurerm_lb_probe" "LoadBalancerHealthProbe" {
    count = "${length(var.healthprobe)}"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    loadbalancer_id = azurerm_lb.LoadBalancer.id
    name = "${lookup(var.healthprobe[count.index], "name")}"
    protocol = "${lookup(var.healthprobe[count.index], "protocol")}"
    port = "${lookup(var.healthprobe[count.index], "port")}"
}

# network interface
resource "azurerm_network_interface" "NetworkInterface" {
    count = var.vm_count
    name = "${var.resource_prefix}_network_interface_${count.index + 1}"
    location = azurerm_resource_group.ResourceGroup.location
    resource_group_name = azurerm_resource_group.ResourceGroup.name

    ip_configuration {
        name = "${var.resource_prefix}_network_interface_configuration"
        subnet_id = data.azurerm_subnet.GetSubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = element(azurerm_public_ip.PublicIP.*.id, count.index)
        # public_ip_address_id = length(azurerm_public_ip.PublicIP.*.id) > 0 ? element(azurerm_public_ip.PublicIP.*.id, count.index) : ""
    }

    tags = {
        "terraform" = "rabbitmq"
    }
}

# # Associate NIC to Backend pool
# resource "azurerm_network_interface_backend_address_pool_association" "NICtoBackEndPool" {
#     count = var.vm_count
#     network_interface_id = element(azurerm_network_interface.NetworkInterface.*.id, count.index)
#     ip_configuration_name = "terraform_network_interface_configuration"
#     backend_address_pool_id = azurerm_lb_backend_address_pool.LoadBalancerBackEndPool.id
# }

# connect the network security group to the network interface
resource "azurerm_network_interface_security_group_association" "NetworkAssociate" {
    count = var.vm_count
    network_interface_id = element(azurerm_network_interface.NetworkInterface.*.id, count.index)
    network_security_group_id = azurerm_network_security_group.NetworkSecurityGroup.id
}

# load balancer backend pool address
resource "azurerm_lb_backend_address_pool_address" "LoadBalancerBackEndPoolAddress" {
    count = var.vm_count
    name = "${var.resource_prefix}_rabbitmq_backend_${count.index + 1}"
    # backend_address_pool_id = element(azurerm_lb_backend_address_pool.LoadBalancerBackEndPool.*.id, count.index)
    backend_address_pool_id = azurerm_lb_backend_address_pool.LoadBalancerBackEndPool.id
    virtual_network_id = data.azurerm_virtual_network.GetVnet.id
    ip_address = element(azurerm_network_interface.NetworkInterface.*.private_ip_address, count.index)
}

# load balancer rule
resource "azurerm_lb_rule" "LoadBalancerRule" {
    depends_on = [
        azurerm_lb_probe.LoadBalancerHealthProbe
    ]
    count = "${length(var.LBRule)}"
    name = "${var.resource_prefix}_${lookup(var.LBRule[count.index], "name")}rabbit_rule"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    loadbalancer_id = azurerm_lb.LoadBalancer.id
    protocol = "${lookup(var.LBRule[count.index], "protocol")}"
    frontend_port = "${lookup(var.LBRule[count.index], "frontend_port")}"
    backend_port = "${lookup(var.LBRule[count.index], "backend_port")}"
    # backend_address_pool_id = element(azurerm_lb_backend_address_pool_address.LoadBalancerBackEndPoolAddress.*.id, count.index)
    backend_address_pool_id = azurerm_lb_backend_address_pool.LoadBalancerBackEndPool.id
    load_distribution = "SourceIP"
    disable_outbound_snat = true
    frontend_ip_configuration_name = "${lookup(var.FrontEndIP[count.index], "name")}"
    probe_id = element(azurerm_lb_probe.LoadBalancerHealthProbe.*.id, count.index)
}

# virtual machine
resource "azurerm_virtual_machine" "VirtualMachine" {
    count = var.vm_count
    name = "${var.resource_prefix}_rabbitmq_${count.index + 1}"
    location = azurerm_resource_group.ResourceGroup.location
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    network_interface_ids = [ element(azurerm_network_interface.NetworkInterface.*.id, count.index) ]
    vm_size = "Standard_DS1_v2"
    delete_os_disk_on_termination = true
    delete_data_disks_on_termination = true

    storage_image_reference {
        publisher = "RedHat"
        offer = "RHEL"
        sku = "8.2"
        version = "latest"
    }

    storage_os_disk {
        name = "${var.resource_prefix}_rabbitmq_os_disk_${count.index + 1}"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "64"
    }

    storage_data_disk {
        name = "${var.resource_prefix}_rabbitmq_data_disk_${count.index + 1}"
        create_option = "Empty"
        lun = 0
        managed_disk_type = "Standard_LRS"
        disk_size_gb = "32"
    }

    os_profile {
        computer_name = "rabbitmq-${count.index + 1}"
        admin_username = "rabbitmqadm"
        admin_password = "Admin12345!"
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }
    
    
    
    tags = {
        "terraform" = "rabbitmq"
    }
}

# Alert action group
resource "azurerm_monitor_action_group" "MonitorActionGroup" {
    count = "${length(var.ActionGroups)}"
    name = "${lookup(var.ActionGroups[count.index], "name")}"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    short_name = "${lookup(var.ActionGroups[count.index], "short_name")}"
    
    email_receiver {
        name = "${lookup(var.ActionGroups[count.index], "email_name")}"
        email_address = "${lookup(var.ActionGroups[count.index], "email_address")}"
    }

}

# # Associate action group to action rule
# resource "azurerm_monitor_action_rule_action_group" "ActionRuleToActionGroup" {
#     name = "${var.resource_prefix}_action_rule_to_action_group"
#     resource_group_name = azurerm_resource_group.ResourceGroup.name
#     action_group_id = azurerm_monitor_action_group.ActionGroup.id
# }

# Activity log alert
resource "azurerm_monitor_activity_log_alert" "MonitorActivityLogsAlert" {
    count = "${length(var.ActivityLogsAlert)}"
    name = "${lookup(var.ActivityLogsAlert[count.index], "name")}"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    scopes = azurerm_virtual_machine.VirtualMachine.*.id
    description = "${lookup(var.ActivityLogsAlert[count.index], "description")}"

    criteria {
        category = "${lookup(var.ActivityLogsAlert[count.index], "category")}"
        operation_name = "${lookup(var.ActivityLogsAlert[count.index], "operation_name")}"
    }

    action {
        action_group_id = azurerm_monitor_action_group.MonitorActionGroup.0.id
    }
    tags = {
        "terraform" = "rabbitmq"
    }
}

# Metric Alert
resource "azurerm_monitor_metric_alert" "MonitorMetricAlert" {
    count = "${length(var.MetricAlert)}"
    name = "${lookup(var.MetricAlert[count.index], "name")}"
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    scopes = azurerm_virtual_machine.VirtualMachine.*.id
    description = "${lookup(var.MetricAlert[count.index], "description")}"
    severity = "${lookup(var.MetricAlert[count.index], "severity")}"
    target_resource_type = "${lookup(var.MetricAlert[count.index], "target_resource_type")}"
    target_resource_location = "${lookup(var.MetricAlert[count.index], "target_resource_location")}"
    criteria {
        metric_namespace = "${lookup(var.MetricAlert[count.index], "metric_namespace")}"
        metric_name = "${lookup(var.MetricAlert[count.index], "metric_name")}"
        aggregation = "${lookup(var.MetricAlert[count.index], "aggregation")}"
        operator = "${lookup(var.MetricAlert[count.index], "operator")}"
        threshold = "${lookup(var.MetricAlert[count.index], "threshold")}"
    }

    action {
        action_group_id = azurerm_monitor_action_group.MonitorActionGroup.0.id
    }
    tags = {
        "terraform" = "rabbitmq"
    }
}
# fetch public ip
data "azurerm_public_ip" "GetPublicIP" {
    count = var.vm_count
    name = element(azurerm_public_ip.PublicIP.*.name, count.index)
    resource_group_name = azurerm_resource_group.ResourceGroup.name
    depends_on = [
        azurerm_virtual_machine.VirtualMachine
    ]
}

# provisioner add inventory
resource "null_resource" "AddInventory" {
    count = var.vm_count
    depends_on = [
        azurerm_virtual_machine.VirtualMachine,
        data.azurerm_public_ip.GetPublicIP
    ]
    # add ip address to ansible inventory
    provisioner "local-exec" {
        command = "./script_add_inventory.sh $ip"
        # command = "echo $ip"
        environment = {
            ip = element(data.azurerm_public_ip.GetPublicIP.*.ip_address, count.index)
        }
    }
}

# provision run ansible
resource "null_resource" "RunAnsible" {
    count = var.vm_count
    depends_on = [
        azurerm_virtual_machine.VirtualMachine,
        data.azurerm_public_ip.GetPublicIP,
        null_resource.AddInventory
    ]

    # run ansible
    provisioner "local-exec" {
        command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbook.yml -e 'ansible_user=rabbitmqadm ansible_password=Admin12345!' --limit $ip"
        # command = "echo $ip"
        environment = {
            ip = element(data.azurerm_public_ip.GetPublicIP.*.ip_address, count.index) 
        }
    }
} 




# show output on terminal
# output "vm_ip_address" {
#     value = {
#         for vm in azurerm_public_ip.PublicIP:
#         vm.name => vm.ip_address
#     }
# }
