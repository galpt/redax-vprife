<#
.SYNOPSIS
    Switch RIFE profiles in a running mpv instance via IPC.
.DESCRIPTION
    Sends a JSON IPC command to a running mpv instance to switch between
    RIFE profiles (rife-720p, rife-1080p, rife-anime) or disable RIFE.
    When called without -Profile, it reads the current profile and toggles
    between rife-720p and off.
    Requires mpv to be started with --input-ipc-server=\\.\pipe\mpv-pipe
    (Windows) or --input-ipc-server=/tmp/mpv-pipe (Unix).
.PARAMETER PipeName
    IPC pipe path.
    Default: \\.\pipe\mpv-pipe (Windows) or /tmp/mpv-pipe (Unix)
.PARAMETER Profile
    Target profile name (rife-720p, rife-1080p, rife-anime, off).
    Default: toggle between rife-720p and off.
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

# ── Toggle logic ────────────────────────────────────────────────────────────
if (-not $Profile) {
    # Read current profile via IPC, then toggle
    $getCmd = @{ command = "get_property"; args = @("current-profile") } | ConvertTo-Json -Compress

    try {
        if ($isWindows) {
            $pipeNameClean = $PipeName.Replace("\\.\pipe\", "")
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeNameClean,
                [System.IO.Pipes.PipeDirection]::InOut)
            $pipe.Connect(2000)
            $writer = New-Object System.IO.StreamWriter($pipe)
            $reader = New-Object System.IO.StreamReader($pipe)
            $writer.WriteLine($getCmd)
            $writer.Flush()
            $response = $reader.ReadLine()
            $writer.Close()
            $reader.Close()
            $pipe.Close()

            $parsed = $response | ConvertFrom-Json -ErrorAction SilentlyContinue
            $current = if ($parsed -and $parsed.data) { $parsed.data } else { "" }
        } else {
            # Unix: use socat for request/response
            $tmpReq = [System.IO.Path]::GetTempFileName()
            $tmpResp = [System.IO.Path]::GetTempFileName()
            $getCmd | Out-File -FilePath $tmpReq -Encoding utf8 -NoNewline
            $null = Start-Process -NoNewWindow -Wait -FilePath "socat" -ArgumentList "$PipeName $tmpReq > $tmpResp 2>&1"
            $current = if (Test-Path $tmpResp) { (Get-Content $tmpResp -Raw | ConvertFrom-Json).data } else { "" }
            Remove-Item $tmpReq, $tmpResp -ErrorAction SilentlyContinue
        }
    } catch {
        $current = ""
    }

    if ($current -and $current -ne "off" -and $current -like "rife-*") {
        $Profile = "off"
    } else {
        $Profile = "rife-720p"
    }

    Write-Host "Current profile: $(if ($current) { $current } else { 'unknown' }) → switching to: $Profile"
}

# ── Send apply-profile command ──────────────────────────────────────────────
$command = @{
    command = "apply-profile"
    args    = @($Profile)
} | ConvertTo-Json -Compress

try {
    if ($isWindows) {
        $pipeNameClean = $PipeName.Replace("\\.\pipe\", "")
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeNameClean,
            [System.IO.Pipes.PipeDirection]::Out)
        $pipe.Connect(1000)
        $writer = New-Object System.IO.StreamWriter($pipe)
        $writer.WriteLine($command)
        $writer.Close()
        $pipe.Close()
    } else {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $command | Out-File -FilePath $tmpFile -Encoding utf8 -NoNewline
        Start-Process -NoNewWindow -Wait -FilePath "socat" -ArgumentList "$PipeName $tmpFile"
        Remove-Item $tmpFile -ErrorAction SilentlyContinue
    }
    Write-Host "Sent: apply-profile $Profile"
} catch {
    Write-Host "Error: Could not connect to mpv IPC at $PipeName" -ForegroundColor Red
    Write-Host "Make sure mpv is running with --input-ipc-server=$PipeName" -ForegroundColor Yellow
    exit 1
}
