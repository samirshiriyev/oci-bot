terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {}
variable "region" {}
variable "ssh_public_key" {}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = var.private_key
  region           = var.region
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ubuntu" {
  compartment_id           = var.tenancy_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_vcn" "oci_vcn" {
  compartment_id = var.tenancy_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "oci-vcn"
}

resource "oci_core_internet_gateway" "oci_ig" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.oci_vcn.id
  display_name   = "oci-ig"
}

resource "oci_core_route_table" "oci_rt" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.oci_vcn.id
  display_name   = "oci-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.oci_ig.id
  }
}

resource "oci_core_subnet" "oci_subnet" {
  compartment_id    = var.tenancy_ocid
  vcn_id            = oci_core_vcn.oci_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "oci-subnet"
  route_table_id    = oci_core_route_table.oci_rt.id
  security_list_ids = [oci_core_vcn.oci_vcn.default_security_list_id]
}

resource "oci_core_instance" "oci_instance" {
  compartment_id      = var.tenancy_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "oracle-free-instance"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.oci_subnet.id
    assign_public_ip = true
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

output "instance_public_ip" {
  value = oci_core_instance.oci_instance.public_ip
}
