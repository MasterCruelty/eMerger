# TODO RIMUOVERE
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"winUpdate.ps1`""

# Install PSWindowsUpdate if not installed
if (!(Get-Module -Name PSWindowsUpdate -ListAvailable)) {
    Write-Host "Installing PSWindowsUpdate..."
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
}

# Windows Update
Write-Host "Updating Windows ..."
Write-Host "At the end reboot your system"
Get-WUInstall -AcceptAll


####### Check installation and update of Chocolatey #######
    # If you wanna install Chocolatey, you need this command
    # Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    #Write-Host "Chocolatey not found. Skipping..."
}

######## Check installation and update Nuget #######
    # If you wanna install Nugetm you need these commands.
    # Invoke-Expression "& { $(irm https://dist.nuget.org/win-x86-commandline/latest/nuget.exe) | Out-File -FilePath $env:temp\nuget.exe }"
    # Move-Item -Path "$env:temp\nuget.exe" -Destination "$env:ProgramFiles\NuGet" -Force
if (!(Get-Command nuget -ErrorAction SilentlyContinue)) {
    Write-Host "NuGet not found. Skipping..."
}

####### Check installation and update scoop #######
    # If you wanna install Scoop, you need this command.
    # Set-ExecutionPolicy RemoteSigned -scope Process; iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
if (!(Test-Path $env:USERPROFILE\scoop)) {
    Write-Host "Scoop not found. Skipping..."
}

Write-Host "Update completed."
