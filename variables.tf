variable "vm_count" {
    description = "Number of virtual machine and other instances that relates"
    default = 3
}

variable "resource_prefix" {
    description = "Prefix name for azure resource"
    default = "terraform"
}

variable "FrontEndIP" {
    description = "FrontEnd IP address for load balancer"
    default = [{
        name = "App_connect"
    },
    {
        name = "Web_console"
    }
    ]
}

variable "LBRule" {
    description = "Load balancer rules"
    default = [{
        name = "App_connect_rule"
        protocol = "Tcp"
        frontend_port = 5672
        backend_port = 5672
    },{
        name = "Web_console_rule"
        protocol = "Tcp"
        frontend_port = 15672
        backend_port = 15672
    }

    ]
}

variable "healthprobe" {
    description = "Health Probe parameters"
    default = [{
        name = "Probe_5672"
        protocol = "Tcp"
        port = 5672
    },
    {
        name = "Probe_15672"
        protocol = "Tcp"
        port = 15672
    }
    ]
}

variable "ActionGroups" {
    description = "Action groups for azure monitor"

    default = [{
        name = "terraform_email_alert"
        short_name = "email_alert"
        email_name = "tinnawat.t"
        email_address = "tinnawat.t@g-able.com"
    }]
}
variable "ActivityLogsAlert" {
    description = "Monitor Activity Logs Alert"

    default = [{
        name = "terraform_deallocate_vm"
        description = "Email alert when stop virtual machine through azure portal (stop vm)"
        category = "Administrative"
        operation_name = "Microsoft.Compute/virtualMachines/deallocate/action"
        level = "Informational"
        resource_type = "Microsoft.Compute/virtualMachines"
    },{
        name = "terraform_poweroff_vm"
        description = "Email alert when shutdown virtual machine"
        category = "Administrative"
        operation_name = "Microsoft.Compute/virtualMachines/powerOff/action"
        level = "Error"
        resource_type = "Microsoft.Compute/virtualMachines"
    }]
}

variable "MetricAlert" {
    description = "Monitor Metric Alert"

    default = [{
        name = "terraform_cpu_warning"
        description = "Email warning when percentage cpu greater than 70 for 5 minute "
        metric_namespace = "Microsoft.Compute/virtualMachines"
        metric_name = "Percentage CPU"
        aggregation = "Average"
        operator = "GreaterThan"
        threshold = 70
        severity = 2
        target_resource_type = "Microsoft.Compute/virtualMachines"
        target_resource_location = "Southeast Asia"
    },{
        name = "terraform_cpu_critical"
        description = "Email alert when percentage cpu greater than 80 for 5 minute "
        metric_namespace = "Microsoft.Compute/virtualMachines"
        metric_name = "Percentage CPU"
        aggregation = "Average"
        operator = "GreaterThan"
        threshold = 80
        severity = 1
        target_resource_type = "Microsoft.Compute/virtualMachines"
        target_resource_location = "Southeast Asia"
    },{
        name = "terraform_memory_warning"
        description = "Email warning when percentage cpu greater than 80 for 5 minute "
        metric_namespace = "Microsoft.Compute/virtualMachines"
        metric_name = "Available Memory Bytes"
        aggregation = "Average"
        operator = "LessThan"
        threshold = 1000000
        severity = 2
        target_resource_type = "Microsoft.Compute/virtualMachines"
        target_resource_location = "Southeast Asia"
    },{
        name = "terraform_memory_citical"
        description = "Email alert when percentage cpu greater than 80 for 5 minute "
        metric_namespace = "Microsoft.Compute/virtualMachines"
        metric_name = "Available Memory Bytes"
        aggregation = "Average"
        operator = "LessThan"
        threshold = 500000
        severity = 1
        target_resource_type = "Microsoft.Compute/virtualMachines"
        target_resource_location = "Southeast Asia"
    }]
}