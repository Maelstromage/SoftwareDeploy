Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

function Read-MultiLineInputBoxDialog([string]$Message, [string]$WindowTitle, [string]$DefaultText)
{


    # Top Label
    $multlabel = New-Object System.Windows.Forms.Label
    $multlabel.Location = New-Object System.Drawing.Size(10,10)
    $multlabel.Size = New-Object System.Drawing.Size(280,20)
    $multlabel.AutoSize = $true
    $multlabel.Text = $Message

    # Text Box
    $multTextBox = New-Object System.Windows.Forms.TextBox
    $multTextBox.Location = New-Object System.Drawing.Size(10,40)
    $multTextBox.Size = New-Object System.Drawing.Size(300,200)
    $multTextBox.AcceptsReturn = $true
    $multTextBox.AcceptsTab = $false
    $multTextBox.Multiline = $true
    $multTextBox.ScrollBars = 'Both'
    $multTextBox.Text = $DefaultText

    # OK Button
    $multOkButton = New-Object System.Windows.Forms.Button
    $multOkButton.Location = New-Object System.Drawing.Size(75,250)
    $multOkButton.Size = New-Object System.Drawing.Size(75,25)
    $multOkButton.Text = "OK"
    $multOkButton.Add_Click({ $multform.Tag = $multTextBox.Text; $multform.Close() })

    # Cancel button
    $multcancelButton = New-Object System.Windows.Forms.Button
    $multcancelButton.Location = New-Object System.Drawing.Size(175,250)
    $multcancelButton.Size = New-Object System.Drawing.Size(75,25)
    $multcancelButton.Text = "Cancel"
    $multcancelButton.Add_Click({ $multform.Tag = $null; $multform.Close() })

    # Form
    $multform = New-Object System.Windows.Forms.Form
    $multform.Text = $WindowTitle
    $multform.Size = New-Object System.Drawing.Size(325,320)
    $multform.FormBorderStyle = 'FixedSingle'
    $multform.StartPosition = "CenterScreen"
    $multform.AutoSizeMode = 'GrowAndShrink'
    $multform.Topmost = $True
    $multform.AcceptButton = $multOkButton
    $multform.CancelButton = $multcancelButton
    $multform.ShowInTaskbar = $true

    # Links Controls
    $multform.Controls.Add($multlabel)
    $multform.Controls.Add($multTextBox)
    $multform.Controls.Add($multOkButton)
    $multform.Controls.Add($multcancelButton)

    # Show form
    $multform.Add_Shown({$multform.Activate()})
    $multform.ShowDialog() > $null  

    # returns text from box
    return $multform.Tag
}





$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = [Environment]::GetFolderPath('Desktop') }
$dScript = ""
$job = @()
$exitCode = @()
for($a = 0; $a -lt 2000; $a++){$exitCode += $null}

$creds = Get-Credential
$comps = Read-MultiLineInputBoxDialog -Message "Paste the list of computers below and hit enter" -WindowTitle "Device List" -defaulttext "Enter devices here..."
#$comps = Read-Host -Prompt "paste the list of computers here and hit enter`n"
$comps = -split $comps
$FileBrowser.Title = "Select file to be deployed"
$null = $FileBrowser.ShowDialog()
#$script = Read-Host -Prompt "paste in the install script for the file" 

if ($FileBrowser.SafeFileName.Substring($FileBrowser.SafeFileName.Length - 4) -eq ".msi" ){
    $dScript = "msiexec.exe /i `"" + $FileBrowser.SafeFileName + "`" /q"
}else {$dScript = $FileBrowser.SafeFileName}
$script = [Microsoft.VisualBasic.Interaction]::InputBox("paste in the install script for the file", "Script", $dScript)
#msiexec.exe /i "program" /q


$comps | foreach{
    Write-Host $_ " " -NoNewline
    New-PSDrive -Name mDrive -PSProvider FileSystem -Root "\\$_\C$" -Credential $creds
    if(!(Test-Path -Path "mDrive:\temp")){
        New-Item -Path "mDrive:\temp" -ItemType directory 
    }
    if(Test-Path -Path "mDrive:\temp"){
        Copy-Item $FileBrowser.FileName "mDrive:\temp\" -verbose -Force
        $job += Invoke-Command -ComputerName $_ -Credential $creds -AsJob -ArgumentList $script -ScriptBlock {
            Param ($script)
            & cd c:\temp\
            & cmd /c $script >> c:\$_.txt
            & cmd /c echo %errorlevel%
        }
        $compName += $_
        Remove-PSDrive -Name mDrive
    }else{Write-Host "Not able to map drive. Check to see if device is reachable."}
}


$continue = $true
do{
    sleep 1
    $x = Read-Host "Hit Enter to see progress, or type q before enter to quit"
    if ($x -eq "q"){$continue = $false}
    $jobCount = 0
    $job | foreach{
        $cJob = receive-Job $_
        if($cJob -ne $null){
            $exitCode[$jobCount]=$cJob
            if($exitCode[$jobCount] -eq 0){$exitCode[$jobCount] = "0 (Success)"}
        }
        Write-Host $_.Location " " $_.state " ExitCode: " $exitCode[$jobCount]
        $jobCount++
    }
}while($continue)
