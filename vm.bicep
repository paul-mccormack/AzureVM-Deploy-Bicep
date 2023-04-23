//Get Location of resources from location of Resource Group
param location string = resourceGroup().location

//Set Name of Virtual Machine
param vmname string = 'TestVMDeploy'

//Set Size of Virtual Machine  ***Make this an allowed list of SKU's***
param vmSku string = 'Standard D2s v3'

//Set Accelerated Networking to True or False  ***This will depend on VM SKU being deployed***
param enableAcceleratedNetworking bool = true

//Local Admin User Name
param adminUserName string = 'scc-admin'

//Prompt for Admin Password  ***Maybe this could be pulled from a KeyVault?***
@secure()
param adminPassword string

//environment() function to create url for post deployment PS script storage account
var storage = environment().suffixes.storage

//Name of vNet
param vnetName string = 'vnet-uks-sandbox-testenv'

//Name of Subnet
param subnetName string = 'snet-uks-sandbox-production'

//Build variable for nic name from VM Name
var nicName = '${vmname}-nic'


@description('Tags. CreatedBy must be declared when run')
param CreatedBy string
@allowed(['Production','Test','Training','Development'])
param Purpose string
@allowed(['DDaT','Place','People','Service Reform'])
param MgtArea string

// Get existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: '${vnetName}/${subnetName}'
}

//Deploy nic Resource
resource nic 'Microsoft.Network/networkInterfaces@2022-09-01' = {
  name: nicName
  location: location
  tags: {
    CreatedBy: CreatedBy
    Purpose: Purpose
    MgtArea: MgtArea
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
}

//Deploy VM Resource
resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' = {
  location: location
  name: vmname
  tags: {
    CreatedBy: CreatedBy
    Purpose: Purpose
    MgtArea: MgtArea
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSku
    }
    storageProfile: {
      osDisk: {
        name:'${vmname}-os-disk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
     computerName: vmname
     adminUsername: adminUserName
     adminPassword: adminPassword
     allowExtensionOperations: true
     windowsConfiguration: {
      provisionVMAgent: true
     }
    }
  }
}

//Post Deployment Script Run
resource postdeploymentscript 'Microsoft.Compute/virtualMachines/runCommands@2022-11-01' = {
  location: location
  parent: vm
  name: 'vmpostDeploymentScript'
  tags: {
    CreatedBy: CreatedBy
    Purpose: Purpose
    MgtArea: MgtArea
  }
  properties: {
    source: {
      scriptUri: 'https://serverdeploymentscripts.blob.${storage}/scripts/serverbuild.ps1'
    }
  }
}

//Output Private IP address of VM.
output ip string = reference(nicName).ipConfigurations[0].properties.privateIPAddress