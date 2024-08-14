# Function to check if the script is running as administrator
function Test-Admin {
    try {
        $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator
        return $currentUser.IsInRole($adminRole)
    } catch {
        Write-Host "Failed to check admin rights: $_" -ForegroundColor Red
        return $false
    }
}

# Function to prompt the user to restart the script with elevated privileges
function Restart-AsAdmin {
    $msg = "This script needs to be run as an administrator.`nPlease close this window, open PowerShell as an administrator, and run the script again."
    Write-Host $msg -ForegroundColor Yellow
    Exit
}

# Check if script is running as administrator and restart if necessary
if (-not (Test-Admin)) {
    Restart-AsAdmin
}

# Load Required Assemblies and XAML for the GUI
Add-Type -AssemblyName PresentationFramework

# Load the main GUI XAML file
try {
    $mainWindowXaml = [System.IO.File]::ReadAllText("$PSScriptRoot\winget_gui.xaml")
    $mainWindowReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($mainWindowXaml))
    $window = [Windows.Markup.XamlReader]::Load($mainWindowReader)
} catch {
    Write-Host "Failed loading the winget_gui.xaml file: $_" -ForegroundColor Red
    exit
}

# Set Global Variables
$excludeFilePath = "excluded_items.txt"
$Global:FilteredPackages = @()

# Function to adjust window size to a percentage of the screen resolution
function Adjust-WindowSize {
    try {
        $screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
        $screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
        $window.Width = $screenWidth * 0.40
        $window.Height = $screenHeight * 0.55
    } catch {
        Write-Host "Failed to adjust window size: $_" -ForegroundColor Red
    }
}

# Function to load initial excluded items from file
function Load-ExcludedItems {
    if (Test-Path -Path $excludeFilePath) {
        try {
            $ExcludeBox = $window.FindName("ExcludeBox")
            $initialExcludeList = Get-Content -Path $excludeFilePath -ErrorAction SilentlyContinue
            foreach ($item in $initialExcludeList -split '\|' | ForEach-Object { $_.Trim() }) {
                $ExcludeBox.Dispatcher.Invoke([action] { $ExcludeBox.Items.Add([PSCustomObject]@{Name = $item }) }, [System.Windows.Threading.DispatcherPriority]::Normal)
            }
            Sort-ExcludeBox
        } catch {
            Write-Host "Failed to load excluded items: $_" -ForegroundColor Red
        }
    }
}

# Function to exclude all packages
function Exclude-AllPackages {
    try {
        $listView = $window.FindName("OutputListView")
        $excludeBox = $window.FindName("ExcludeBox")

        foreach ($item in $listView.Items) {
            $exists = $excludeBox.Items | Where-Object { $_.Name -eq $item.Name }
            if ($null -eq $exists) {
                $excludeBox.Dispatcher.Invoke([action] { $excludeBox.Items.Add([PSCustomObject]@{Name = $item.Name }) }, [System.Windows.Threading.DispatcherPriority]::Normal)
            }
        }
        Sort-ExcludeBox
        Update-ExcludeList
        Get-Upgradable-Packages
    } catch {
        Write-Host "Failed to exclude all packages: $_" -ForegroundColor Red
    }
}

# Function to update and save the exclude list to a file
function Update-ExcludeList {
    try {
        $ExcludeBox = $window.FindName("ExcludeBox")
        $ExcludeBox.Items | ForEach-Object { $_.Name } | Out-File -FilePath $excludeFilePath -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Failed to update exclude list: $_" -ForegroundColor Red
    }
}

# Function to handle ListView and ExcludeBox interactions
function Handle-ListViewItemInteraction {
    try {
        $ExcludeBox = $window.FindName("ExcludeBox")
        $OutputListView = $window.FindName("OutputListView")
        $selectedItem = $OutputListView.SelectedItem
        if ($null -ne $selectedItem) {
            $name = $selectedItem.Name
            $existsInExclude = $ExcludeBox.Items | Where-Object { $_.Name -eq $name }

            if ($null -ne $existsInExclude) {
                $ExcludeBox.Dispatcher.Invoke([action] { $ExcludeBox.Items.Remove($existsInExclude) }, [System.Windows.Threading.DispatcherPriority]::Normal)
            } else {
                $ExcludeBox.Dispatcher.Invoke([action] { $ExcludeBox.Items.Add([PSCustomObject]@{Name = $name }) }, [System.Windows.Threading.DispatcherPriority]::Normal)
            }
            Sort-ExcludeBox
            Sort-OutputListView
            Update-ExcludeList
        }
    } catch {
        Write-Host "Failed to handle ListView item interaction: $_" -ForegroundColor Red
    }
}

# Function to dynamically adjust ListView and ExcludeBox column widths
function Adjust-ColumnWidths {
    try {
        Adjust-Widths $window.FindName("OutputListView")
        Adjust-Widths $window.FindName("ExcludeBox")
    } catch {
        Write-Host "Failed to adjust column widths: $_" -ForegroundColor Red
    }
}

function Adjust-Widths($listView) {
    try {
        if ($listView.IsLoaded) {
            $totalWidth = $listView.ActualWidth

            if ($totalWidth -le 0) {
                Write-Host "Actual width is too small to adjust columns properly."
                return
            }

            if ($listView -eq $window.FindName("ExcludeBox")) {
                $columns = $listView.View.Columns
                if ($columns.Count -ge 1) {
                    $columns[0].Width = $totalWidth  # Name column
                } else {
                    Write-Host "Not enough columns to adjust widths."
                }
            }
            if ($listView -eq $window.FindName("OutputListView")) {
                $columns = $listView.View.Columns
                if ($columns.Count -ge 4) {
                    $columns[0].Width = $totalWidth * 0.38  # Name column
                    $columns[1].Width = $totalWidth * 0.38  # ID column
                    $columns[2].Width = $totalWidth * 0.12  # Version column
                    $columns[3].Width = $totalWidth * 0.12  # Available column
                } else {
                    Write-Host "Not enough columns to adjust widths."
                }
            }
        } else {
            Write-Host "ListView is not loaded yet."
        }
    } catch {
        Write-Host "Failed to adjust widths: $_" -ForegroundColor Red
    }
}

# Functions related to package listing and updating
$global:DebugMode = $false

function Get-Upgradable-Packages {
    try {
        Write-Host "Listing upgradable packages..."
        $excludeList = $window.FindName("ExcludeBox").Items | ForEach-Object { $_.Name }
        $upgradablePackages = winget upgrade --accept-source-agreements | Out-String -Stream

        $listView = $window.FindName("OutputListView")
        $listView.Dispatcher.Invoke([action] { $listView.Items.Clear() }, [System.Windows.Threading.DispatcherPriority]::Normal)

        $Global:FilteredPackages = Get-FilteredPackages $upgradablePackages $excludeList

        foreach ($package in $Global:FilteredPackages) {
            if ($excludeList -notcontains $package.Name) {
                Write-Host "Adding package to UI: $($package.Name)"
                $listView.Dispatcher.Invoke([action] { $listView.Items.Add($package) }, [System.Windows.Threading.DispatcherPriority]::Normal)
            }
        }
        Sort-OutputListView
        Write-Host "Completed listing upgradable packages."
    } catch {
        Write-Host "Failed to list upgradable packages: $_" -ForegroundColor Red
    }
}

function Update-Upgradable {
    try {
        if ($Global:FilteredPackages.Count -eq 0) {
            Write-Host "No packages to update." -ForegroundColor Red
            return
        }

        $UpdateUpgradableButton.IsEnabled = $false

        Write-Host "Starting the Update process..." -ForegroundColor Green
        Write-Host "Total packages to update: $($Global:FilteredPackages.Count)"

        $completedJobs = 0
        $successfulUpdates = 0
        $totalPackages = $Global:FilteredPackages.Count

        $jobStatuses = @()

        foreach ($package in $Global:FilteredPackages) {
            $job = Start-Job -ScriptBlock {
                param($package)
                try {
                    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                    $command = "winget upgrade --id $($package.ID) --accept-source-agreements --accept-package-agreements --ignore-security-hash --silent"
                    $output = Invoke-Expression $command 2>&1
                    $exitCode = $LASTEXITCODE
                    if ($exitCode -ne 0 -or $output -match "Error" -or $output -match "failed" -or $output -match "No available upgrade found") {
                        return "Error updating package $($package.Name): $output"
                    }
                    return "Successfully updated package $($package.Name)"
                } catch {
                    return "Error updating package $($package.Name): $_"
                }
            } -ArgumentList $package

            $jobStatuses += [PSCustomObject]@{
                Job = $job
                Package = $package
            }
        }

        while ($completedJobs -lt $totalPackages) {
            foreach ($jobStatus in $jobStatuses) {
                $job = $jobStatus.Job
                if ($job.State -eq 'Completed') {
                    $completedJobs++
                    $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                    Remove-Job -Job $job -Force

                    if ($result -match "^Error") {
                        Write-Host $result -ForegroundColor Red
                    } else {
                        Write-Host $result -ForegroundColor Green
                        $successfulUpdates++
                    }
                }
            }
            Start-Sleep -Milliseconds 500
        }

        $UpdateUpgradableButton.IsEnabled = $true
        Get-Upgradable-Packages

        Write-Host "Update process completed. Total updated: $successfulUpdates out of $totalPackages" -ForegroundColor Green
    } catch {
        Write-Host "Failed to update packages: $_" -ForegroundColor Red
        $UpdateUpgradableButton.IsEnabled = $true
    }
}

function Get-FilteredPackages {
    param($upgradablePackages, $excludeList)
    $filteredPackages = @()
    $isDataSection = $false

    foreach ($line in $upgradablePackages) {
        if ($line -match '^-{2,}') {
            $isDataSection = $true
            continue
        }

        if (-not $isDataSection) {
            continue
        }

        if ($line -match '^The following packages') {
            break
        }

        if ($line -match '^\s*(\S.+?)\s{2,}(\S+)\s+((?:<|>)?\s*\S+)\s+(\S+)\s+(\S.+)$') {
            $name, $id, $version, $available, $source = $matches[1], $matches[2], $matches[3], $matches[4], $matches[5]
            if ($excludeList -notcontains $name -and $name -ne "Name" -and $id -ne "Id") {
                $package = [PSCustomObject]@{
                    Name = $name; ID = $id; Version = $version; Available = $available; Source = $source
                }
                $filteredPackages += $package
            }
        }
    }

    return $filteredPackages
}

function Restore-Excluded {
    try {
        $excludeBox = $window.FindName("ExcludeBox")
        $excludeBox.Dispatcher.Invoke([action] { $excludeBox.Items.Clear() }, [System.Windows.Threading.DispatcherPriority]::Normal)

        $excludeItems = $excludeBox.Items | ForEach-Object { $_.Name }
        $excludeItems | Out-File -FilePath $excludeFilePath -ErrorAction SilentlyContinue 

        Get-Upgradable-Packages
    } catch {
        Write-Host "Failed to restore excluded items: $_" -ForegroundColor Red
    }
}

# Function to sort the ExcludeBox items alphabetically
function Sort-ExcludeBox {
    try {
        $ExcludeBox = $window.FindName("ExcludeBox")
        $items = $ExcludeBox.Items | Sort-Object -Property Name
        $ExcludeBox.Dispatcher.Invoke([action] {
            $ExcludeBox.Items.Clear()
            foreach ($item in $items) {
                $ExcludeBox.Items.Add($item)
            }
        }, [System.Windows.Threading.DispatcherPriority]::Normal)
    } catch {
        Write-Host "Failed to sort ExcludeBox: $_" -ForegroundColor Red
    }
}

# Function to sort the OutputListView items alphabetically
function Sort-OutputListView {
    try {
        $OutputListView = $window.FindName("OutputListView")
        $items = $OutputListView.Items | Sort-Object -Property Name
        $OutputListView.Dispatcher.Invoke([action] {
            $OutputListView.Items.Clear()
            foreach ($item in $items) {
                $OutputListView.Items.Add($item)
            }
        }, [System.Windows.Threading.DispatcherPriority]::Normal)
    } catch {
        Write-Host "Failed to sort OutputListView: $_" -ForegroundColor Red
    }
}

# Setup the GUI events and display the window
function Initialize-Gui {
    try {
        $window.Add_Loaded({
            Adjust-WindowSize
            Write-Host "Loaded AdjustWindowSize." -ForegroundColor Blue
            Adjust-ColumnWidths
            Write-Host "Loaded AdjustColumnWidths." -ForegroundColor Blue
            Load-ExcludedItems
            Write-Host "Loaded LoadExcludedItems." -ForegroundColor Blue
            Get-Upgradable-Packages
            Write-Host "Loaded ListUpgradable." -ForegroundColor Blue
        })

        $window.Add_SizeChanged({ Adjust-ColumnWidths })

        $listView = $window.FindName("OutputListView")
        $listView.Add_MouseDoubleClick({ Handle-ListViewItemInteraction })
        $listView.Add_KeyDown({
            if ($_.Key -eq "Enter") {
                Handle-ListViewItemInteraction
            }
        })

        $ExcludeBox = $window.FindName("ExcludeBox")
        $ExcludeBox.Add_MouseDoubleClick({
            $selectedExclude = $ExcludeBox.SelectedItem
            if ($null -ne $selectedExclude) {
                $ExcludeBox.Dispatcher.Invoke([action] { $ExcludeBox.Items.Remove($selectedExclude) }, [System.Windows.Threading.DispatcherPriority]::Normal)
                Sort-ExcludeBox
                Update-ExcludeList
                Get-Upgradable-Packages
            }
        })
        $ExcludeBox.Add_KeyDown({
            if ($_.Key -eq "Enter") {
                $selectedExclude = $ExcludeBox.SelectedItem
                if ($null -ne $selectedExclude) {
                    $ExcludeBox.Dispatcher.Invoke([action] { $ExcludeBox.Items.Remove($selectedExclude) }, [System.Windows.Threading.DispatcherPriority]::Normal)
                    Sort-ExcludeBox
                    Update-ExcludeList
                    Get-Upgradable-Packages
                }
            }
        })

        $UpdateUpgradableButton = $window.FindName("UpdateUpgradableButton")
        $UpdateUpgradableButton.Add_Click({ Update-Upgradable })
        $excludeAllButton = $window.FindName("ExcludeAllButton")
        $excludeAllButton.Add_Click({ Exclude-AllPackages })
        $restoreExcludedButton = $window.FindName("RestoreExcludedButton")
        $restoreExcludedButton.Add_Click({ Restore-Excluded })
        $listUpgradableButton = $window.FindName("ListUpgradableButton")
        $listUpgradableButton.Add_Click({ Get-Upgradable-Packages })

        $window.ShowDialog()
    } catch {
        Write-Host "Failed to setup GUI: $_" -ForegroundColor Red
    }
}

Write-Host "Function SetupGui." -ForegroundColor Blue
Initialize-Gui
