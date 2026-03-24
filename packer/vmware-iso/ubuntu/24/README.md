
## Dependencies

- Packer
- vmware-iso
- vmware-vphere
- [Windows Assessment and Deployment Kit (ADK)](https://go.microsoft.com/fwlink/?linkid=2120254)
  - Requires Windows ADK: Download and install the Windows ADK, then choose "Deployment Tools" during installation.
  - could not find a supported CD ISO creation command (the supported commands are: xorriso, mkisofs, hdiutil, oscdimg)
executar no powershell como administrador

`netsh advfirewall firewall add rule name="Packer HTTP" dir=in action=allow protocol=TCP localport=8000-9000`
