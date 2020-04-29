# managed-ocp

BC Gov OpenShift Container Platform deployment automation

## Getting Started

We are going to be using a set of tools to manage OpenShift cluster deployments.

These tools are:

* bash
* terraform
* vscode
* asdf version manager
* platform specific CLIs and plugins

### Prerequisites

For each specific platform, run the installer to get started.

For example, to use IBM, run

```bash
#!/bin/bash
cd platforms/ibm;
./prerequisites.sh;
```

## Deploy Infrastructure via Terraform

### Setup

Run the following command (which is expected to complete in around 20 minutes). When Terraform starts processing the script, it will prompt if the action should be applied.  Read carefully and if so, type ```yes```.

```bash
#!/bin/bash
cd platforms/ibm/cluster;
terraform apply;
```

After Terraform is processing the script, you will receive a chain of emails that your IBM Cloud Order # 12345678 has been approved.

### Teardown

Run the following command (which is expected to complete in around 4 minutes). When Terraform starts processing the script, it will prompt if the action should be applied.  Read carefully and if so, type ```yes```.

```bash
#!/bin/bash
cd platforms/ibm/cluster;
terraform destroy;
```
