# Fusion-io ioDrive Duo on Windows 11

Practical notes for making a legacy Fusion-io ioDrive Duo usable on Windows 11, then combining its two 320 GB modules into one striped NTFS volume.

## What this covers

- Identifying an unknown PCIe storage card by PCI hardware ID and `fio-status`
- Installing the compatible legacy Fusion-io/SanDisk VSL package
- Verifying the driver and both modules in Windows
- Creating a Windows Storage Spaces **Simple** (striped, no redundancy) virtual disk
- Formatting it as GPT/NTFS with a 64 KiB allocation unit

## Hardware and driver

The tested device was a Fusion-io ioDrive Duo 640 GB, presented to Windows as two 320 GB modules. The working package was the 64-bit Dell/SanDisk bundle containing:

`Dell_IO_Management_3.2.15.1699_x64.exe`

The installed VSL driver reported version `3.2.15`, build `1699`, and the provider was SanDisk. This is legacy software. Obtain it from a reputable archive or the hardware vendor's support materials, verify its digital signature, and scan downloads before use. Do not redistribute proprietary installer binaries in this repository.

## Installation sequence

1. Record the PCI hardware IDs in Device Manager. The tested family used vendor `1AED`, device `1005`.
2. Install the 64-bit Dell/SanDisk IO Management package as Administrator.
3. Reboot.
4. Confirm the driver in Device Manager and confirm the card appears in Disk Management or PowerShell.
5. If the card reports minimal mode or channel initialization errors, check firmware compatibility before attempting a low-level format. Do not flash firmware from a bundle that does not explicitly support the card's part number.

Useful checks:

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'PCI\\VEN_1AED&DEV_1005*' }
Get-Disk | Where-Object FriendlyName -like '*Fusion*'
Get-PhysicalDisk | Where-Object FriendlyName -like '*Fusion*'
```

If the vendor utility is installed, run `fio-status -a` from an elevated terminal. A healthy Windows presentation should also show two online disks of approximately 320 GB each.

## Create the striped volume

The included [`create-fusionio-stripe.ps1`](create-fusionio-stripe.ps1) creates a fixed-provisioned Storage Spaces Simple virtual disk from exactly two poolable Fusion-io disks. It initializes GPT, assigns the next available drive letter, and formats the volume as NTFS with a 64 KiB allocation unit and the label `FusionIO`.

Run it from **PowerShell as Administrator**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& .\\create-fusionio-stripe.ps1
```

The script intentionally refuses to proceed unless it finds exactly two poolable disks named `Fusion ioCache 320GB`. Review the selected disks before adapting it for different hardware.

## Important warnings

- A Simple layout is RAID-0-like striping: it improves aggregate throughput but has no redundancy. Failure of either module loses the volume.
- Creating the pool and formatting the virtual disk destroys existing data on the selected disks.
- Do not use this volume for irreplaceable data without a separate backup.
- Legacy VSL software may not be supported by current Windows releases. Keep a recovery path and expect that a future Windows update could break the driver.
- Firmware updates and low-level formats are device-specific. Use only firmware that explicitly matches the card part number and revision.

## Results to expect

For two 320 GB modules, expect a usable volume around 635 GB after Storage Spaces metadata and filesystem overhead. The volume should report:

- Label: `FusionIO`
- File system: `NTFS`
- Virtual-disk resiliency: `Simple`
- Two columns
- Healthy/OK status

## License

The documentation and script are released under the MIT License. Vendor software remains the property of its respective owner and is not included.
