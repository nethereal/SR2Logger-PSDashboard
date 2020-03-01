If ($runspaces) {
    while ($runspaces.Status.IsCompleted -notcontains $true) {}
    foreach ($runspace in $runspaces ) {
        $results += $runspace.Pipe.EndInvoke($runspace.Status)
        $runspace.Pipe.Dispose()
    }
    $pool.Close() 
    $pool.Dispose()
}


$ScriptDir = "C:\PSSR2Logger\PSSR2Dashboard"
Set-Location $ScriptDir

$craft = $null
$craft = .\spacecraft.ps1

Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}



$sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
$pool = [RunspaceFactory]::CreateRunspacePool(1, [int]20, $sessionstate, $Host)
$pool.ApartmentState = "MTA"
$pool.Open()
$runspaces = $results = @()

$ReceiverSB = {
    param($craft)
    $LogPort = 2873;
    Function Read([byte[]]$data) {
        $stream = [System.IO.MemoryStream]::new($data)
        $reader = [System.IO.BinaryReader]::new($stream)
        [hashtable]$tmphash = @{}
        do {
            [int]$length = $reader.ReadUInt16();
            [byte[]]$name = @($null)*$length;
            $reader.Read($name,0,$length) | Out-Null;
            $propPath = [System.Text.Encoding]::Default.GetString($name) -split "_"
            $propVal = $null
            [int]$type = $reader.ReadByte();
            switch ($type) {
                0       { $propVal = $null }
                1       { $propVal = $reader.ReadDouble() }
                2       { $propVal = $reader.ReadBoolean() }
                3       { $propVal = @($reader.ReadDouble(),$reader.ReadDouble(),$reader.ReadDouble()) }
                default { $propVal = "UnknownType" }
            }
            $tmphash.Add("$($propPath[0])$($propPath[1])",$propVal)
        } while ($stream.Position -lt $stream.Length)
        ForEach ($key in $tmphash.Keys) { $craft."$key" = $tmphash."$key" }
        $reader.Dispose();
        $stream.Dispose();
    }
    If ($script:cli) { $script:cli.Dispose(); }
    [System.Net.Sockets.UdpClient]$script:cli = [System.Net.Sockets.UdpClient]::new($LogPort);
    If ($ep) { $ep = $null; } 
    $ep = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any,$LogPort);
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds(600)
    do { If ($script:cli.Available -gt 0) { Read($script:cli.Receive([ref]$ep)) } } 
    while ($true -and (get-date) -lt $endTime)
    $script:cli.Dispose(); $ep = $null;
}

$VelocityWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "VelocityLateral",
        "VelocityVertical",
        "VelocityMachNumber",
        "VelocityOrbit",
        "VelocityAcceleration",
        "VelocitySurface",
        "VelocityGravity",
        "VelocityTarget",
        "VelocityAngular"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,303'
    $Form.text                       = "Velocity"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Velocity"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 300

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 281
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
Lateral`r`n
Vertical`r`n
Mach`r`n
Orbit(x,y,z)`r`n
 `r`n
 `r`n
Accel(x,y,z)`r`n
 `r`n
 `r`n
Surface(x,y,z)`r`n
 `r`n
 `r`n
Gravity(x,y,z)`r`n
 `r`n
 `r`n
Target(x,y,z)`r`n
 `r`n
 `r`n
Angular(x,y,z)`r`n
 `r`n
 `r`n
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 100
    $llogtbRight.height                   = 281
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 40
    $llogtbUnits.height                   = 281
    $llogtbUnits.location                 = New-Object System.Drawing.Point(206,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
m\s`r`n
m\s`r`n
`r`n
"@
    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        #$mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),$SR2Loc.TopLeft.Y)
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y + 121 + 339))
        #                                                   (($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$PerformanceWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "PerformanceCurrentISP",
        "PerformanceEngineThrust",
        "PerformanceMass",
        "PerformanceMaxEngineThrust",
        "PerformanceStageBurnTime",
        "PerformanceStageDeltaV",
        "PerformanceTWR"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,121'
    $Form.text                       = "Performance"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Performance"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 99
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
CurrentISP
EngThrust
Mass
MaxEngThrust
StgBurnTime
StgDeltaV
TWR
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 99
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 30
    $llogtbUnits.height                   = 99
    $llogtbUnits.location                 = New-Object System.Drawing.Point(216,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
s`r`n
N`r`n
kg`r`n
N
s
∆v

"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y + 339))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$NavWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "NavAngleOfAttack",
        "NavBankAngle",
        "NavCraftPitchAxis",
        "NavCraftRollAxis",
        "NavCraftYawAxis",
        "NavEast",
        "NavHeading",
        "NavNorth",
        "NavPitch",
        "NavPosition",
        "NavSideSlip",
        "NavTargetPosition"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,367'
    $Form.text                       = "Nav"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Nav"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 95
    $llogtb.height                   = 345
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
AngOfAtk
BankAng
Heading
Pitch
SideSlip
Pitch(x,y,z)


Roll(x,y,z)


Yaw(x,y,z)


East(x,y,z)


North(x,y,z)


Position(x,y,z)


TrgtPos(x,y,z)


"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 345
    $llogtbRight.location                 = New-Object System.Drawing.Point(99,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 35
    $llogtbUnits.height                   = 345
    $llogtbUnits.location                 = New-Object System.Drawing.Point(211,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
Deg
Deg
Deg
Deg
Deg




















"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y + 121 + 339 + 81))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,3))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",3))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$InputWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "InputBrake",
        "InputPitch",
        "InputRoll",
        "InputYaw",
        "InputSlider1",
        "InputSlider2",
        "InputThrottle",
        "InputTranslateForward",
        "InputTranslateRight",
        "InputTranslateUp"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '100,159'
    $Form.text                       = "Input"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Input"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 75
    $llogtb.height                   = 137
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
Brake
Pitch
Roll
Yaw
Slider1
Slider2
Throttle
TrnsFwd
TrnsRight
TrnsUp
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 55
    $llogtbRight.height                   = 137
    $llogtbRight.location                 = New-Object System.Drawing.Point(79,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        #$mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y + 339))

        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + (248 * 2)),($SR2Loc.TopLeft.Y + 339 + 159))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,3))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",3))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}


$AGWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "ActivationGroup1",
        "ActivationGroup2",
        "ActivationGroup3",
        "ActivationGroup4",
        "ActivationGroup5",
        "ActivationGroup6",
        "ActivationGroup7",
        "ActivationGroup8",
        "ActivationGroup9",
        "ActivationGroup10"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '100,159'
    $Form.text                       = "AG Status"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "AG Status"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 70

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 85
    $llogtb.height                   = 137
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
  AG   1
  AG   2
  AG   3
  AG   4
  AG   5
  AG   6
  AG   7
  AG   8
  AG   9
  AG   10
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 45
    $llogtbRight.height                   = 137
    $llogtbRight.location                 = New-Object System.Drawing.Point(89,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White



    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + (248 * 2)),($SR2Loc.TopLeft.Y + 339))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { $tmptxt = $tmptxt + "$($craft."$_")`r" }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$MapWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '632,339'
    $Form.text                       = "Map - Droo"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Map - Droo"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400
    $nullbl.SendToBack()

    $PictureBox1                     = New-Object system.Windows.Forms.PictureBox
    $PictureBox1.width               = 628
    $PictureBox1.height              = 304
    $PictureBox1.location            = New-Object System.Drawing.Point(2,25)
    $img                             = Get-Item "C:\pssr2logger\PSSR2Dashboard\Equirectangular.bmp"
    $PictureBox1.image               = [System.Drawing.Image]::Fromfile($img)
    $PictureBox1.SizeMode            = [System.Windows.Forms.PictureBoxSizeMode]::zoom

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y))
        $mainform.topmost = $true
        
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($nullbl,$PictureBox1))
    $Form.ShowDialog() | Out-Null
    $PictureBox1.SendToFront()
    $nullbl.Focus()
}

$TimeWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "TimeFrameDeltaTime",
        "TimeTimeSinceLaunch",
        "TimeTotalTime"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,67'
    $Form.text                       = "Time"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Time"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 45
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
FrameDelta
SinceLaunch
Total
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 45
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 30
    $llogtbUnits.height                   = 45
    $llogtbUnits.location                 = New-Object System.Drawing.Point(216,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
s`r`n
s`r`n
s`r`n
"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y + 339))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$AltitudeWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "AltitudeAGL",
        "AltitudeASL"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,56'
    $Form.text                       = "Altitude"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Altitude"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 32
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
AGL
ASL
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 32
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 30
    $llogtbUnits.height                   = 32
    $llogtbUnits.location                 = New-Object System.Drawing.Point(216,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
m`r`n
m`r`n
"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y + 339 + 67))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}



$NameWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "NameCraft",
        "NamePlanet",
        "NameTargetName",
        "NameTargetPlanet"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '100,81'
    $Form.text                       = "Name"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Name"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 75
    $llogtb.height                   = 59
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
Craft
Planet
TrgtName
TrgtPlnt
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 55
    $llogtbRight.height                   = 59
    $llogtbRight.location                 = New-Object System.Drawing.Point(79,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + (248 * 2)),($SR2Loc.TopLeft.Y + 339 + 159 + 159))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            $tmptxt = $tmptxt + "$($craft."$_")`r"
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}





$MiscWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "MiscGrounded",
        "MiscSolarRadiation"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '100,54'
    $Form.text                       = "Misc"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Misc"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 75
    $llogtb.height                   = 32
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
Grounded
SolRad
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 55
    $llogtbRight.height                   = 32
    $llogtbRight.location                 = New-Object System.Drawing.Point(79,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + (248 * 2)),($SR2Loc.TopLeft.Y + 339 + 159 + 159 + 81))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            if ("$_" -eq 'MiscGrounded') {
                $tmptxt = $tmptxt + " $($craft."$_")`r"
            } elseIf ("$_" -eq 'MiscSolarRadiation') {
                $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",2))`r"
            }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$FuelWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "FuelAllStages",
        "FuelBattery",
        "FuelMono",
        "FuelStage"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,81'
    $Form.text                       = "Fuel"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Fuel"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 300

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 59
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
AllStages
Battery
Mono
Stage
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 100
    $llogtbRight.height                   = 59
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 40
    $llogtbUnits.height                   = 59
    $llogtbUnits.location                 = New-Object System.Drawing.Point(206,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
%`r`n
%`r`n
%`r`n
%
"@
    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        #$mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),$SR2Loc.TopLeft.Y)
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y + 121 + 339 + 303))
        #                                                   (($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$OrbitWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "OrbitApoapsis",
        "OrbitEccentricity",
        "OrbitInclination",
        "OrbitPeriapsis",
        "OrbitPeriod",
        "OrbitTimeToApoapsis",
        "OrbitTimeToPeriapsis"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,119'
    $Form.text                       = "Orbit"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Orbit"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 300

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 100
    $llogtb.height                   = 97
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
Apoapsis
Eccentricity
Inclination
Periapsis
Period
TimeToApo
TimeToPeri
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 100
    $llogtbRight.height                   = 97
    $llogtbRight.location                 = New-Object System.Drawing.Point(104,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 40
    $llogtbUnits.height                   = 97
    $llogtbUnits.location                 = New-Object System.Drawing.Point(206,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
m`r`n
`r`n
Deg`r`n
m`r`n
s`r`n
s`r
s`r`n
"@
    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        #$mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),$SR2Loc.TopLeft.Y)
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y + 121 + 339 + 303 + 81))
        #                                                   (($SR2Loc.BottomRight.X - 8 + 248),($SR2Loc.TopLeft.Y))

        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,5))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",5))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$AtmosphereWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "AtmosphereAirDensity",
        "AtmosphereAirPressure",
        "AtmosphereSpeedOfSound",
        "AtmosphereTemperature"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,81'
    $Form.text                       = "Atmosphere"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Atmosphere"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 95
    $llogtb.height                   = 59
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
AirDensity
AirPressure
SpdOfSnd
Temperature
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 59
    $llogtbRight.location                 = New-Object System.Drawing.Point(99,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 35
    $llogtbUnits.height                   = 59
    $llogtbUnits.location                 = New-Object System.Drawing.Point(211,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
kg/m3
Pa
m/s
K
"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y + 121 + 339))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,3))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",3))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$PlanetWindowSB = {
    param($craft)
    
    Add-Type -AssemblyName System.Drawing
    $path = "C:\PSSR2Logger\PSSR2Dashboard\*.ttf"
    $ttffiles = Get-ChildItem $path
    $fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
    $ttffiles | ForEach-Object { $fontCollection.AddFontFile($_.fullname) }
    $FontAnita = $fontCollection.Families[0]

    Function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784   

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe
        
    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {        
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

    $RGBBackground = [System.Drawing.Color]::FromArgb(39,44,46);
    $RGBText = [System.Drawing.Color]::FromArgb(10,172,222);
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Props = @(
        "CurrentPlanetAtmosphereHeight",
        "CurrentPlanetChildPlanetsCount",
        "CurrentPlanetCraftsCount",
        "CurrentPlanetMass",
        "CurrentPlanetName",
        "CurrentPlanetParent",
        "CurrentPlanetRadius",
        "CurrentPlanetSolarPosition"
    )

    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '248,170'
    $Form.text                       = "Planet"
    $Form.TopMost                    = $false
    $Form.BackColor                  = $RGBBackground
    $Form.ForeColor                  = $RGBText
    $Form.FormBorderStyle            = [System.Windows.Forms.BorderStyle]::None
    $Form.MaximizeBox                = $false
    $Form.MinimizeBox                = $false

    $nullbl                          = New-Object System.Windows.Forms.Label
    $nullbl.Text                     = "Planet"
    $nullbl.Location                 = New-Object System.Drawing.Point(2,2)
    $nullbl.Font                     = [System.Drawing.Font]::new($FontAnita,9,[System.Drawing.FontStyle]::Bold)
    $nullbl.ForeColor                = $RGBText
    $nullbl.Size.Width               = 400

    $llogtb                          = New-Object system.Windows.Forms.TextBox
    $llogtb.Enabled                  = $false
    #$llogtb.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtb.multiline                = $true
    $llogtb.width                    = 95
    $llogtb.height                   = 148
    $llogtb.location                 = New-Object System.Drawing.Point(2,20)
    $llogtb.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtb.ForeColor                = [System.Drawing.Color]::White
    $llogtb.BackColor                = $RGBBackground
    $llogtb.Text = @"
AtmHeight m
ChildPlntsCnt
CraftsCount
Mass Kg
Name
Parent
Radius m
SolPos(x,y,z)
`r
`r
"@

    $llogtbRight                          = New-Object system.Windows.Forms.TextBox
    $llogtbRight.Enabled                  = $false
    #$llogtbRight.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbRight.BackColor                = $RGBBackground
    $llogtbRight.multiline                = $true
    $llogtbRight.width                    = 110
    $llogtbRight.height                   = 148
    $llogtbRight.location                 = New-Object System.Drawing.Point(99,20)
    $llogtbRight.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbRight.ForeColor                = [System.Drawing.Color]::White


    $llogtbUnits                          = New-Object system.Windows.Forms.TextBox
    $llogtbUnits.Enabled                  = $false
    #$llogtbUnits.BorderStyle              = [System.Windows.Forms.BorderStyle]::None
    $llogtbUnits.BackColor                = $RGBBackground
    $llogtbUnits.multiline                = $true
    $llogtbUnits.width                    = 35
    $llogtbUnits.height                   = 148
    $llogtbUnits.location                 = New-Object System.Drawing.Point(211,20)
    $llogtbUnits.Font                     = [System.Drawing.Font]::new($FontAnita,8)
    $llogtbUnits.ForeColor                = [System.Drawing.Color]::White
    $llogtbUnits.Text = @"
m


Kg


m



"@

    $Timer1 = New-Object System.Windows.Forms.Timer
    $Timer1.Interval = 300
    $Timer1.Enabled = $true
    $Timer1SB = { 
        Param($mainform)
        $SR2Loc = Get-Process SimpleRockets2 | Get-Window
        $mainform.Location = New-Object System.Drawing.Point(($SR2Loc.BottomRight.X - 8),($SR2Loc.TopLeft.Y + 121 + 339 + 81 + 367))
        $mainform.topmost = $true
        $tmptxt = ""
        $props | % { 
            If ($craft."$_".Count -gt 1) { ForEach ($val in $craft."$_") { $tmptxt = $tmptxt + " $([Math]::Round($val,3))`r`n" } } 
            Else { $tmptxt = $tmptxt + " $([Math]::Round($craft."$_",3))`r`n" }
        }
        $llogtbRight.Text = $tmptxt
    }
    
    $Timer1.add_tick({Invoke-Command $Timer1SB -ArgumentList $Form})
    $Timer1.Start()
    $Form.controls.AddRange(@($llogtb,$llogtbRight,$llogtbUnits,$nullbl))
    $Form.ShowDialog() | Out-Null
    $nullbl.Focus()
}

$ReceiverSBrunspace = [PowerShell]::Create().AddScript($ReceiverSB).AddArgument($craft.state)
$ReceiverSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $ReceiverSBrunspace; Status = $ReceiverSBrunspace.BeginInvoke() }

$VelocityWindowSBrunspace = [PowerShell]::Create().AddScript($VelocityWindowSB).AddArgument($craft.state)
$VelocityWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $VelocityWindowSBrunspace; Status = $VelocityWindowSBrunspace.BeginInvoke() }

$PerformanceWindowSBrunspace = [PowerShell]::Create().AddScript($PerformanceWindowSB).AddArgument($craft.state)
$PerformanceWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $PerformanceWindowSBrunspace; Status = $PerformanceWindowSBrunspace.BeginInvoke() }

$NavWindowSBrunspace = [PowerShell]::Create().AddScript($NavWindowSB).AddArgument($craft.state)
$NavWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $NavWindowSBrunspace; Status = $NavWindowSBrunspace.BeginInvoke() }

$InputWindowSBrunspace = [PowerShell]::Create().AddScript($InputWindowSB).AddArgument($craft.state)
$InputWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $InputWindowSBrunspace; Status = $InputWindowSBrunspace.BeginInvoke() }

$AGWindowSBrunspace = [PowerShell]::Create().AddScript($AGWindowSB).AddArgument($craft.state)
$AGWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $AGWindowSBrunspace; Status = $AGWindowSBrunspace.BeginInvoke() }

$MapWindowSBrunspace = [PowerShell]::Create().AddScript($MapWindowSB).AddArgument($craft.state)
$MapWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $MapWindowSBrunspace; Status = $MapWindowSBrunspace.BeginInvoke() }

$TimeWindowSBrunspace = [PowerShell]::Create().AddScript($TimeWindowSB).AddArgument($craft.state)
$TimeWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $TimeWindowSBrunspace; Status = $TimeWindowSBrunspace.BeginInvoke() }

$AltitudeWindowSBrunspace = [PowerShell]::Create().AddScript($AltitudeWindowSB).AddArgument($craft.state)
$AltitudeWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $AltitudeWindowSBrunspace; Status = $AltitudeWindowSBrunspace.BeginInvoke() }

$NameWindowSBrunspace = [PowerShell]::Create().AddScript($NameWindowSB).AddArgument($craft.state)
$NameWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $NameWindowSBrunspace; Status = $NameWindowSBrunspace.BeginInvoke() }

$MiscWindowSBrunspace = [PowerShell]::Create().AddScript($MiscWindowSB).AddArgument($craft.state)
$MiscWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $MiscWindowSBrunspace; Status = $MiscWindowSBrunspace.BeginInvoke() }

$FuelWindowSBrunspace = [PowerShell]::Create().AddScript($FuelWindowSB).AddArgument($craft.state)
$FuelWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $FuelWindowSBrunspace; Status = $FuelWindowSBrunspace.BeginInvoke() }

$OrbitWindowSBrunspace = [PowerShell]::Create().AddScript($OrbitWindowSB).AddArgument($craft.state)
$OrbitWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $OrbitWindowSBrunspace; Status = $OrbitWindowSBrunspace.BeginInvoke() }

$AtmosphereWindowSBrunspace = [PowerShell]::Create().AddScript($AtmosphereWindowSB).AddArgument($craft.state)
$AtmosphereWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $AtmosphereWindowSBrunspace; Status = $AtmosphereWindowSBrunspace.BeginInvoke() }

$PlanetWindowSBrunspace = [PowerShell]::Create().AddScript($PlanetWindowSB).AddArgument($craft.state)
$PlanetWindowSBrunspace.RunspacePool = $pool
$runspaces += [PSCustomObject]@{ Pipe = $PlanetWindowSBrunspace; Status = $PlanetWindowSBrunspace.BeginInvoke() }

while ($runspaces.Status.IsCompleted -notcontains $true) {}
foreach ($runspace in $runspaces ) {
    $results += $runspace.Pipe.EndInvoke($runspace.Status)
    $runspace.Pipe.Dispose()
}
$pool.Close() 
$pool.Dispose()