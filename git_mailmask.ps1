param(
    [switch]$AutoPush
)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =================================================
#   Git Mail Mask
# =================================================
Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "   Git Mail Mask - Interactive Mode" -ForegroundColor White
Write-Host "=================================================`n" -ForegroundColor Cyan

# Multi-selection menu (with pagination)
function Show-MultiSelectMenu {
    param($Options)
    
    $Selected = @()
    for ($k = 0; $k -lt $Options.Length; $k++) { $Selected += $false }
    
    $Cursor = 0
    $PageSize = 10

    # Console pre-allocation
    for ($i = 0; $i -le $PageSize + 2; $i++) { Write-Host "" }
    $MenuTop = [Console]::CursorTop - ($PageSize + 3)

    [Console]::CursorVisible = $false
    [Console]::TreatControlCAsInput = $true
    $NeedsRedraw = $true

    try {
        while ($true) {
            if ($NeedsRedraw) {
                [Console]::SetCursorPosition(0, $MenuTop)

                $StartIdx = [math]::Floor($Cursor / $PageSize) * $PageSize
                $CurrentPage = [math]::Floor($Cursor / $PageSize) + 1
                $TotalPages = [math]::Ceiling($Options.Length / $PageSize)

                Write-Host "   --- Page $CurrentPage / $TotalPages --- (Arrows to scroll, Space to select, Enter to validate)" -ForegroundColor DarkGray

                $PadLen = [Math]::Max(0, [Console]::WindowWidth - 6)

                for ($i = $StartIdx; $i -lt ($StartIdx + $PageSize); $i++) {
                    if ($i -lt $Options.Length) {
                        if ($i -eq $Cursor) {
                            Write-Host "> " -NoNewline -ForegroundColor Cyan
                        } else {
                            Write-Host "  " -NoNewline
                        }

                        if ($Selected[$i]) {
                            Write-Host "(X) " -NoNewline -ForegroundColor Green
                        } else {
                            Write-Host "( ) " -NoNewline
                        }

                        $Text = $Options[$i]
                        if ($Text.Length -gt $PadLen -and $PadLen -gt 0) { $Text = $Text.Substring(0, $PadLen) }
                        Write-Host $Text.PadRight($PadLen)
                    } else {
                        Write-Host "".PadRight($PadLen + 6)
                    }
                }
                $NeedsRedraw = $false
            }

            $KeyInfo = [Console]::ReadKey($true)
            $Key = $KeyInfo.Key

            if ($KeyInfo.Modifiers -match "Control" -and $Key -eq "C") {
                [Console]::SetCursorPosition(0, $MenuTop + $PageSize + 2)
                Write-Host "`n[Cancelled] Exited by user." -ForegroundColor Red
                exit
            }

            if ($Key -eq "UpArrow") {
                $Cursor--
                if ($Cursor -lt 0) { $Cursor = $Options.Length - 1 }
                $NeedsRedraw = $true
            } elseif ($Key -eq "DownArrow") {
                $Cursor++
                if ($Cursor -ge $Options.Length) { $Cursor = 0 }
                $NeedsRedraw = $true
            } elseif ($Key -eq "Spacebar") {
                $Selected[$Cursor] = -not $Selected[$Cursor]
                $NeedsRedraw = $true
            } elseif ($Key -eq "Enter") {
                break
            }
        }
    } finally {
        [Console]::TreatControlCAsInput = $false
        [Console]::CursorVisible = $true
    }

    [Console]::SetCursorPosition(0, $MenuTop + $PageSize + 2)

    $Result = @()
    for ($i = 0; $i -lt $Options.Length; $i++) {
        if ($Selected[$i]) { 
            $Result += $Options[$i] 
        }
    }
    return ,$Result
}

# Single selection menu
function Show-SingleSelectMenu {
    param($Options)
    
    $Cursor = 0

    for ($i = 0; $i -lt $Options.Length; $i++) { Write-Host "" }
    $MenuTop = [Console]::CursorTop - $Options.Length

    [Console]::CursorVisible = $false
    [Console]::TreatControlCAsInput = $true
    $NeedsRedraw = $true

    try {
        while ($true) {
            if ($NeedsRedraw) {
                [Console]::SetCursorPosition(0, $MenuTop)

                for ($i = 0; $i -lt $Options.Length; $i++) {
                    if ($i -eq $Cursor) {
                        Write-Host "> " -NoNewline -ForegroundColor Cyan
                        Write-Host "(X) " -NoNewline -ForegroundColor Green
                    } else {
                        Write-Host "  " -NoNewline
                        Write-Host "( ) " -NoNewline
                    }

                    Write-Host $Options[$i]
                }
                $NeedsRedraw = $false
            }

            $KeyInfo = [Console]::ReadKey($true)
            $Key = $KeyInfo.Key

            if ($KeyInfo.Modifiers -match "Control" -and $Key -eq "C") {
                [Console]::SetCursorPosition(0, $MenuTop + $Options.Length)
                Write-Host "`n[Cancelled] Exited by user." -ForegroundColor Red
                exit
            }

            if ($Key -eq "UpArrow") {
                $Cursor--
                if ($Cursor -lt 0) { $Cursor = $Options.Length - 1 }
                $NeedsRedraw = $true
            } elseif ($Key -eq "DownArrow") {
                $Cursor++
                if ($Cursor -ge $Options.Length) { $Cursor = 0 }
                $NeedsRedraw = $true
            } elseif ($Key -eq "Enter") {
                break
            }
        }
    } finally {
        [Console]::TreatControlCAsInput = $false
        [Console]::CursorVisible = $true
    }

    [Console]::SetCursorPosition(0, $MenuTop + $Options.Length)
    
    return $Cursor
}

# 1. Dependencies
if (-not (Get-Command "git-filter-repo" -ErrorAction SilentlyContinue)) {
    Write-Host "[Error] git-filter-repo not found. Run: pip install git-filter-repo" -ForegroundColor Red
    exit
}

# 2. Identity
Write-Host "NEW IDENTITY :" -ForegroundColor Yellow
$DefaultName = ""
$DefaultEmail = ""
$EmailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

if (Get-Command "gh" -ErrorAction SilentlyContinue) {
    # Fetch gh api async
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.Open()
    $PowerShell = [powershell]::Create().AddScript({ gh api user })
    $PowerShell.Runspace = $Runspace
    $AsyncResult = $PowerShell.BeginInvoke()
    
    $Frames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    $Counter = 0
    [Console]::CursorVisible = $false
    
    # Loader
    while (-not $AsyncResult.IsCompleted) {
        Write-Host -NoNewline "`r$($Frames[$Counter % $Frames.Length]) Fetching GitHub profile..." -ForegroundColor Cyan
        $Counter++
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host -NoNewline ("`r" + " " * 50 + "`r")
    [Console]::CursorVisible = $true
    
    $Result = $PowerShell.EndInvoke($AsyncResult)
    $Runspace.Close()
    $PowerShell.Dispose()
    
    if ($Result) {
        $UserInfo = $Result | ConvertFrom-Json
        $DefaultName = $UserInfo.login
        $DefaultId = $UserInfo.id
        if (-not [string]::IsNullOrWhiteSpace($DefaultName) -and -not [string]::IsNullOrWhiteSpace($DefaultId)) {
            $DefaultEmail = "$DefaultId+$DefaultName@users.noreply.github.com"
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($DefaultName)) {
    $CorrectName = Read-Host "- GitHub Username [Enter for: $DefaultName]"
    if ([string]::IsNullOrWhiteSpace($CorrectName)) { $CorrectName = $DefaultName }

    while ($true) {
        $CorrectEmail = Read-Host "- GitHub Email [Enter for: $DefaultEmail]"
        if ([string]::IsNullOrWhiteSpace($CorrectEmail)) { $CorrectEmail = $DefaultEmail }

        if ($CorrectEmail -match $EmailRegex) { break }
        Write-Host "  [Error] Invalid email format. Please try again." -ForegroundColor Red
    }
} else {
    $CorrectName = Read-Host "- GitHub Username (ex: Cold-FR)"

    while ($true) {
        $CorrectEmail = Read-Host "- GitHub Email (ex: noreply@github.com)"
        if ($CorrectEmail -match $EmailRegex) { break }
        Write-Host "  [Error] Invalid email format. Please try again." -ForegroundColor Red
    }
}
Write-Host ""

# 3. Emails to replace
Write-Host "OLD EMAILS TO REPLACE :" -ForegroundColor Yellow
Write-Host "   (Leave empty and press Enter to finish)" -ForegroundColor DarkGray
$OldEmails = @()

while ($true) {
    $OldEmail = Read-Host "   >"
    if ([string]::IsNullOrWhiteSpace($OldEmail)) { break }

    if ($OldEmail -match $EmailRegex) {
        $OldEmails += $OldEmail
    } else {
        Write-Host "   [Error] Invalid email format." -ForegroundColor Red
    }
}

if ($OldEmails.Count -eq 0) { Write-Host "[Error] No email provided." -ForegroundColor Red; exit }
Write-Host ""

# 4. Source selection
Write-Host "REPOSITORY SOURCE :" -ForegroundColor Yellow
Write-Host "   (Arrows to choose, Enter to validate)" -ForegroundColor DarkGray

$CurrentDirPath = (Get-Location).Path
$SourceOptions = @(
    "Enter a remote repository URL manually",
    "Connect to GitHub and select from my repositories",
    "Process the current directory ($CurrentDirPath)",
    "Enter the path to a local repository manually"
)

$RepoChoiceIndex = Show-SingleSelectMenu -Options $SourceOptions
Write-Host ""

$Repos = @()
$IsLocal = $false

if ($RepoChoiceIndex -eq 0) {
    $SingleRepo = Read-Host "Enter the repository URL"
    if ([string]::IsNullOrWhiteSpace($SingleRepo)) { Write-Host "[Cancelled] Empty URL." -ForegroundColor Red; exit }
    $Repos += $SingleRepo
} elseif ($RepoChoiceIndex -eq 1) {
    if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
        Write-Host "[Error] GitHub CLI (gh) not found." -ForegroundColor Red
        exit
    }
    
    Write-Host "Connecting to GitHub and fetching repositories..." -ForegroundColor Cyan
    $AllGithubRepos = @(gh repo list --limit 100 --json url --jq ".[].url")
    
    if ($AllGithubRepos.Count -eq 0) {
        Write-Host "[Error] No repository found." -ForegroundColor Red; exit
    }

    Write-Host "`nSELECT REPOSITORIES TO CLEAN :" -ForegroundColor Yellow
    
    $Repos = Show-MultiSelectMenu -Options $AllGithubRepos
    
    if ($Repos.Count -eq 0) { Write-Host "[Cancelled] No repository selected." -ForegroundColor Red; exit }
} elseif ($RepoChoiceIndex -eq 2) {
    if (-not (Test-Path ".git")) {
        Write-Host "[Error] Current directory is not a git repository." -ForegroundColor Red
        exit
    }
    $Repos += $CurrentDirPath
    $IsLocal = $true
} elseif ($RepoChoiceIndex -eq 3) {
    $SingleRepo = Read-Host "Enter the path to your local repository"
    # Clean quotes if user drag & dropped a folder
    $SingleRepo = $SingleRepo -replace '^"|"$', '' -replace "^'|'$", ''

    if ([string]::IsNullOrWhiteSpace($SingleRepo) -or -not (Test-Path $SingleRepo)) {
        Write-Host "[Cancelled] Invalid path." -ForegroundColor Red; exit
    }

    # Resolve to absolute path
    $ResolvedPath = (Resolve-Path $SingleRepo).Path
    $Repos += $ResolvedPath
    $IsLocal = $true
}
Write-Host ""

# 5. Process filter-repo
Write-Host "STARTING CLEANUP ($($Repos.Count) repository(ies) selected)..." -ForegroundColor Cyan
$OriginalDir = Get-Location
$WorkDir = "git_mailmask_temp"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# We use absolute path for mailmap since we will CD into repositories
$MailmapFile = Join-Path $OriginalDir "$WorkDir\mailmap.txt"
$MailmapContent = @()
foreach ($Old in $OldEmails) {
    $MailmapContent += "$CorrectName <$CorrectEmail> <$Old>"
}
Set-Content -Path $MailmapFile -Value $MailmapContent -Encoding UTF8

foreach ($Repo in $Repos) {
    Write-Host "-------------------------------------------------"

    if ($IsLocal) {
        Write-Host "Processing local repository : $Repo" -ForegroundColor Yellow
        Set-Location $Repo
        if (-not (Test-Path ".git")) {
            Write-Host "[Error] Not a git repository. Skipping." -ForegroundColor Red
            Set-Location $OriginalDir
            continue
        }
    } else {
        Write-Host "Processing remote repository : $Repo" -ForegroundColor Yellow
        Set-Location $OriginalDir
        Set-Location $WorkDir

        git clone $Repo
        $FolderName = ($Repo -split "/")[-1] -replace "\.git$",""
        Set-Location $FolderName

        # Check branches
        $Branches = git branch -r | Where-Object { $_ -notmatch "->" }
        foreach ($Branch in $Branches) {
            $BranchName = $Branch.Trim()
            $LocalBranch = $BranchName -replace "^origin/", ""
            git branch --track $LocalBranch $BranchName 2>$null
        }
    }

    # Backup origin URL because filter-repo deletes remotes
    $OriginUrl = git remote get-url origin 2>$null

    # Apply mailmap
    git filter-repo --mailmap $MailmapFile --force

    # Restore origin
    if ($OriginUrl) {
        git remote add origin $OriginUrl
    } elseif (-not $IsLocal) {
        git remote add origin $Repo
    }

    # Push Execution
    Write-Host "`nHistory successfully rewritten locally!" -ForegroundColor Green

    if ($AutoPush) {
        Write-Host "Auto-push flag detected. Pushing to remote..." -ForegroundColor Cyan
        git push --force --tags origin "refs/heads/*" 2>$null
        if ($LASTEXITCODE -ne 0) {
            git push --force --tags 2>$null
        }
    } else {
        $PushConfirm = Read-Host "Do you want to force push to the remote? [Y/n]"
        if ($PushConfirm -notmatch "^[nN]") {
            git push --force --tags origin "refs/heads/*" 2>$null
            if ($LASTEXITCODE -ne 0) {
                git push --force --tags 2>$null
            }
        } else {
            Write-Host "Skipping push for this repository." -ForegroundColor DarkGray
        }
    }

    Set-Location $OriginalDir
}

# 6. Cleanup
Set-Location $OriginalDir
Remove-Item -Recurse -Force -Path $WorkDir

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "OPERATION COMPLETED SUCCESSFULLY !" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan