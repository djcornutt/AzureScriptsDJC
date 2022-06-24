<#  ************************************************************************************************
    This script automates all steps in the creation of a Azure Compute Gallery Definition,
    Gallery Version using the image created in the beginning steps from the reference VM's snapshot.
    If the disk name is identical to another disk in this sub (in case of a VM pipelined clone), 
    then this script will fail. If you do not need all steps then comment out your local branch copy. 
    For example, if you are just creating a new version in the Gallery Definition. 
    
    Drew Cornutt - Microsoft
    *************************************************************************************************
    #>

#Set params
$VmRG = 'Reference VMs Resource Group'
$ImageVm = 'Reference VMs Name'
$imageName = 'Name of Image to be created' #give it a unique name
$ImageDefinition = 'This name will display in Compute Gallery' #give it a name that follows customer naming convention

#   1.  Get source VM plan information: 

$vm = Get-azvm `
    -ResourceGroupName $VmRG `
    -Name $ImageVm
$vm.Plan

#   2.  Get Gallery Information 

$gallery = Get-AzGallery `
    -Name Existing_Compute_Gallery `
    -ResourceGroupName RG_for_the_above

#   3. snap the image VM then create image from snapshot

$Disk = (Get-AzDisk -name $vm.StorageProfile.OsDisk.Name)
$snapConfig = New-AzSnapshotConfig -SourceUri $ManualID -CreateOption Copy -Location $vm.Location 
$snapshotname = ($vm.name + '_snapshot')

New-AzSnapshot  -ResourceGroupName $VmRG `
    -SnapshotName $snapshotname `
    -Snapshot $snapConfig

Write-Host "Created snapshot $($snapshotname) successfully"

$snapshot = Get-AzSnapshot -ResourceGroupName $VmRG -SnapshotName $snapshotName

$imageConfig = New-AzImageConfig -Location $vm.location
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsState Generalized -OsType Linux -SnapshotId $snapshot.Id

New-AzImage -ImageName $imageName -ResourceGroupName $VmRG -Image $imageConfig

# 4. Create the image definition:

Get-AzImage -name $imageName 

#change -Sku to a unique value
$imageDefinition = New-AzGalleryImageDefinition `
    -GalleryName $gallery.Name `
    -ResourceGroupName $gallery.ResourceGroupName `
    -Location $gallery.Location `
    -Name $ImageDefinition `
    -OsState specialized `
    -OsType Linux `
    -Publisher 'Can be anything' `
    -Offer 'Can be anything' `
    -Sku 'Can be anything but must be unique' `
    -PurchasePlanPublisher $vm.Plan.Publisher `
    -PurchasePlanProduct $vm.Plan.Product `
    -PurchasePlanName  $vm.Plan.Name

#   4.  Lastly, create a new image version, dont use the Portal as it is buggy for this function. 

New-AzGalleryImageVersion `
    -ResourceGroupName $gallery.ResourceGroupName `
    -GalleryName $gallery.Name `
    -GalleryImageDefinitionName $ImageDefinition.Name `
    -Name '1.0.0' `
    -Location $gallery.Location `
    -SourceImageID $vm.Id
    





