param(
    [Parameter(HelpMessage='folder on target host where assets are copied')]
    $targetFolder,
    [Parameter(HelpMessage='Results folder')]
    $resultsFolder="results",
    [Parameter(HelpMessage = 'Podman Download URL')]
    $downloadUrl='https://api.cirrus-ci.com/v1/artifact/github/containers/podman/Artifacts/binary/podman-remote-release-windows_amd64.zip',
    [Parameter(HelpMessage='Podman version')]
    $version='4.8.0-dev',
    [Parameter(HelpMessage = 'Initialize podman machine, default is 0/false')]
    $initialize='0',
    [Parameter(HelpMessage = 'Start Podman machine, default is 0/false')]
    $start='0',
    [Parameter(HelpMessage = 'Podman machine rootful flag, default 0/false')]
    $rootful='0'
)

write-host "Print out script parameters, usefull for debugging..."
$ParametersList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
foreach ($key in $ParameterList.keys) {
    $variable = Get-Variable -Name $key -ErrorAction SilentlyContinue;
    if($variable) {
        write-host "$($variable.name) > $($variable.value)"
    }
}

# Function to check if a command is available
function Command-Exists($command) {
    $null = Get-Command -Name $command -ErrorAction SilentlyContinue
    return $?
}

Write-Host "Podman desktop E2E - podman nightly install script is being run..."

write-host "Switching to a target folder: " $targetFolder
cd $targetFolder
write-host "Create a resultsFolder in targetFolder: $resultsFolder"
mkdir -p $resultsFolder
$workingDir=Get-Location
write-host "Working location: " $workingDir

# Specify the user profile directory
$userProfile = $env:USERPROFILE

# Specify the shared tools directory
$toolsInstallDir = Join-Path $userProfile 'tools'

# Output file for built podman desktop binary
$outputFile = "podman-location.log"

# Force install of WSL
wsl -l -v
$installed=$?

if (!$installed) {
    Write-Host "installing wsl2"
    wsl --set-default-version 2
    wsl --install --no-distribution
    $distroMissing=$?
    if($distroMissing) {
        write-host "Wsl enabled, but distro is missing, installing default distro..."
        wsl --install --no-launch
    }
}

if (-not (Command-Exists "podman")) {
    # Download and install the nightly podman for windows
    $podmanFolder="podman-remote-release-windows_amd64"
    write-host "Downloading podman archive from $downloadUrl"
    if (-not (Test-Path -Path "$toolsInstallDir\podman" -PathType Container)) {
        Invoke-WebRequest -Uri $downloadUrl -OutFile "$toolsInstallDir\podman.zip"
        Expand-Archive -Path "$toolsInstallDir\podman.zip" -DestinationPath $toolsInstallDir -Force
    }
    $env:Path += ";$toolsInstallDir\podman-$version\usr\bin"
    # store the podman installation
    cd "$workingDir\$resultsFolder"
    write-host "Podman installation path will be stored in $outputFile"
    "$toolsInstallDir\podman-$version\usr\bin" | Out-File -FilePath $outputFile -NoNewline
}

# Setup podman machine in the host system
if ($initialize -eq "1") {
    $flags=''
    if ($rootful -eq "1") {
        $flags="--rootful"
    }
    write-host "Initializing podman machine, command: podman machine init $flags"
    $logFile = "$workingDir\$resultsFolder\podman-machine-init.log"
    "podman machine init $flags" > $logFile
    if($flags) {
        # If more flag will be necessary, we have to consider composing the command other way
        # ie. https://stackoverflow.com/questions/6604089/dynamically-generate-command-line-command-then-invoke-using-powershell
        podman machine init $flags >> $logFile
    } else {
        podman machine init >> $logFile
    }
    if ($start -eq "1") {
        write-host "Starting podman machine..."
        "podman machine start" >> $logfile
        podman machine start >> $logFile
    }
    podman machine ls >> $logFile
} else {
    write-host "Podman installed, no machine prepared..."
}

write-host "Script finished..."
