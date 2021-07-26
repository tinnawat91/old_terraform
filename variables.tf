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