# Start Powershell as administrator
Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"winUpdate.ps1`""

