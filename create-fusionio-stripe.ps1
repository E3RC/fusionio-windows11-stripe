$ErrorActionPreference = 'Stop'

$fioDisks = @(Get-PhysicalDisk | Where-Object {
    $_.FriendlyName -eq 'Fusion ioCache 320GB' -and $_.CanPool
})

if ($fioDisks.Count -ne 2) {
    throw "Expected exactly 2 poolable Fusion ioCache 320GB disks; found $($fioDisks.Count)."
}

if (Get-StoragePool -FriendlyName 'FusionIO_Pool' -ErrorAction SilentlyContinue) {
    throw 'FusionIO_Pool already exists; refusing to overwrite it.'
}

$subsystem = Get-StorageSubsystem | Select-Object -First 1
if (-not $subsystem) { throw 'No Windows Storage subsystem was found.' }

New-StoragePool -FriendlyName 'FusionIO_Pool' `
    -StorageSubsystemFriendlyName $subsystem.FriendlyName `
    -PhysicalDisks $fioDisks | Out-Host

New-VirtualDisk -StoragePoolFriendlyName 'FusionIO_Pool' `
    -FriendlyName 'FusionIO' `
    -ResiliencySettingName Simple `
    -ProvisioningType Fixed `
    -UseMaximumSize | Out-Host

Start-Sleep -Seconds 3
$disk = Get-VirtualDisk -FriendlyName 'FusionIO' | Get-Disk
if ($disk.PartitionStyle -eq 'RAW') {
    Initialize-Disk -Number $disk.Number -PartitionStyle GPT | Out-Host
}

$partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -AssignDriveLetter
Format-Volume -Partition $partition -FileSystem NTFS `
    -AllocationUnitSize 65536 -NewFileSystemLabel 'FusionIO' -Confirm:$false | Out-Host

Get-Volume -FileSystemLabel 'FusionIO' |
    Format-List DriveLetter, FileSystemLabel, FileSystem, Size, SizeRemaining, HealthStatus
