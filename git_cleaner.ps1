[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =================================================
#   Git History Cleaner
# =================================================
Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "   Git History Cleaner - Interactive Mode" -ForegroundColor White
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
    $NeedsRedraw = $true

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
                    # Clear padding
                    Write-Host "".PadRight($PadLen + 6)
                }
            }
            $NeedsRedraw = $false
        }

        $KeyInfo = [Console]::ReadKey($true)
        $Key = $KeyInfo.Key

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

    [Console]::CursorVisible = $true
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
    $NeedsRedraw = $true

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

    [Console]::CursorVisible = $true
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
    
    $CorrectEmail = Read-Host "- GitHub Email [Enter for: $DefaultEmail]"
    if ([string]::IsNullOrWhiteSpace($CorrectEmail)) { $CorrectEmail = $DefaultEmail }
} else {
    $CorrectName = Read-Host "- GitHub Username (ex: Cold-FR)"
    $CorrectEmail = Read-Host "- GitHub Email (ex: noreply@github.com)"
}
Write-Host ""

# 3. Emails to replace
Write-Host "OLD EMAILS TO REPLACE :" -ForegroundColor Yellow
Write-Host "   (Leave empty and press Enter to finish)" -ForegroundColor DarkGray
$OldEmails = @()
while ($true) {
    $OldEmail = Read-Host "   >"
    if ([string]::IsNullOrWhiteSpace($OldEmail)) { break }
    $OldEmails += $OldEmail
}
if ($OldEmails.Count -eq 0) { Write-Host "[Error] No email provided." -ForegroundColor Red; exit }
Write-Host ""

# 4. Source selection
Write-Host "REPOSITORY SOURCE :" -ForegroundColor Yellow
Write-Host "   (Arrows to choose, Enter to validate)" -ForegroundColor DarkGray

$SourceOptions = @(
    "Enter a repository URL manually",
    "Connect to GitHub and select from my repositories"
)

$RepoChoiceIndex = Show-SingleSelectMenu -Options $SourceOptions
Write-Host ""

$Repos = @()
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
}
Write-Host ""

# 5. Process filter-repo
Write-Host "STARTING CLEANUP ($($Repos.Count) repository(ies) selected)..." -ForegroundColor Cyan
$WorkDir = "git_cleaner_temp"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir

$MailmapFile = "mailmap.txt"
$MailmapContent = @()
foreach ($Old in $OldEmails) {
    $MailmapContent += "$CorrectName <$CorrectEmail> <$Old>"
}
Set-Content -Path $MailmapFile -Value $MailmapContent -Encoding UTF8

foreach ($RepoUrl in $Repos) {
    Write-Host "-------------------------------------------------"
    Write-Host "Processing : $RepoUrl" -ForegroundColor Yellow

    git clone $RepoUrl
    $FolderName = ($RepoUrl -split "/")[-1] -replace "\.git$",""
    Set-Location $FolderName

    # Check branches
    $Branches = git branch -r | Where-Object { $_ -notmatch "->" }
    foreach ($Branch in $Branches) {
        $BranchName = $Branch.Trim()
        $LocalBranch = $BranchName -replace "^origin/", ""
        git branch --track $LocalBranch $BranchName 2>$null
    }

    # Apply mailmap
    git filter-repo --mailmap "..\$MailmapFile" --force

    git remote add origin $RepoUrl
    git push --force --tags origin "refs/heads/*" 
    
    Set-Location ..
}

# 6. Cleanup
Set-Location ..
Remove-Item -Recurse -Force -Path $WorkDir

Write-Host "`n=================================================" -ForegroundColor Cyan
Write-Host "OPERATION COMPLETED SUCCESSFULLY !" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan