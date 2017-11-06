# Set all the networks as "Private" to allow WinRM connections
$ScriptFromGithHub = Invoke-WebRequest -Uri https://raw.githubusercontent.com/ferrarimarco/packer-windows/1.0.0/floppy/fixnetwork.ps1 -UseBasicParsing
Invoke-Expression $($ScriptFromGithHub.Content)
