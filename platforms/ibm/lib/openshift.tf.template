variable "ibmcloud_api_key" {
  description       = "Allows connection to IBM Cloud via IBM Cloud CLI"
}

provider "ibm" {
  ibmcloud_api_key      = var.ibmcloud_api_key
}

resource "ibm_container_cluster" "cluster" {
  name              = "bcgov-ocp"
  datacenter        = "mon01"
  default_pool_size = 3
  machine_type      = "b3c.4x16"
  hardware          = "shared"
  kube_version      = "4.3_openshift"
  public_vlan_id    = "<public_vlan_ID>"
  private_vlan_id   = "<private_vlan_ID>"
  lifecycle {
    ignore_changes = [kube_version]
  }
}
