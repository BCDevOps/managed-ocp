resource "ibm_container_cluster" "cluster" {
  name              = "bcgov-ocp"
  datacenter        = "dal10"
  default_pool_size = 3
  machine_type      = "b3c.4x16"
  hardware          = "shared"
  kube_version      = "3.11_openshift"
  public_vlan_id    = "<public_vlan_ID>"
  private_vlan_id   = "<private_vlane_ID>"
  lifecycle {
    ignore_changes = ["kube_version"]
  }
}