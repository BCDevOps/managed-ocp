provider "ibm" {
  ibmcloud_api_key      = var.ibmcloud_api_key
  iaas_classic_username = var.iaas_classic_username
  iaas_classic_api_key  = var.iaas_classic_api_key
}

resource "ibm_container_cluster" "cluster" {
  name              = "bcgov-ocp"
  datacenter        = "mon01"
  default_pool_size = 3
  machine_type      = "b3c.4x16"
  hardware          = "shared"
  kube_version      = "4.3.2_openshift"
  public_vlan_id    = "<public_vlan_ID>"
  private_vlan_id   = "<private_vlan_ID>"
  lifecycle {
    ignore_changes = [kube_version]
  }
}
