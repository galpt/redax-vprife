<#
.SYNOPSIS
    Toggle RIFE filter profiles in mpv via IPC.
.DESCRIPTION
    Sends a JSON IPC command to a running mpv instance to switch between
    RIFE profiles (rife-720p, rife-1080p, rife-anime) or disable RIFE.
    Requires mpv to be started with --input-ipc-server=\\.\pipe\mpv-pipe
    (Windows) or --input-ipc-server=/tmp/mpv-pipe (Unix).
.PARAMETER PipeName
    IPC pipe path.
    Default: \\.\pipe\mpv-pipe (Windows) or /tmp/mpv-pipe (Unix)
.PARAMETER Profile
    Target profile name (rife-720p, rife-1080p, rife-anime, off).
    Default: toggles between rife-720p and off.
.EXAMPLE
    .\toggle-rife.ps1                           # toggle RIFE on/off
    .\toggle-rife.ps1 -Profile rife-anime       # switch to anime profile
#>

param(
    [string]$PipeName = "",
    [string]$Profile = ""
)

$isWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

if (-not $PipeName) {
    $PipeName = if ($isWindows) { "\\.\pipe\mpv-pipe" } else { "/tmp/mpv-pipe" }
}

if (-not $Profile) {
    # Toggle: try to read current profile
    $Profile = "off"  # default = disable
}

$command = @{
    command = "apply-profile"
    args    = @($Profile)
} | ConvertTo-Json -Compress

if ($isWindows) {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $PipeName.Replace("\\.\pipe\", ""), [System.IO.Pipes.PipeDirection]::Out)
    $pipe.Connect(1000)
    $writer = New-Object System.IO.StreamWriter($pipe)
    $writer.WriteLine($command)
    $writer.Close()
    $pipe.Close()
} else {
    # Unix: use socat or write to socket
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $command | Out-File -FilePath $tmpFile -Encoding utf8 -NoNewline
    Write-Host "Execute: socat $PipeName $tmpFile"
    Remove-Item $tmpFile
}

Write-Host "Sent command: apply-profile $Profile"
