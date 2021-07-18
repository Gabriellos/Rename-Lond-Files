function Get-WorkingHomeDirectory {
    param (
        # Set username folder
        [Parameter(Mandatory=$true)]
        [String]$Username
    )

    Process {
        $PathToDirectory = 'F:\home\' + $Username
        return $PathToDirectory
    }
}

function  Sort-Object {
    param (
        [Parameter(Mandatory=$true)]
        $ArrayOfFolders
    )
    $Temp
    for ($i = 1; $i -lt $ArrayOfFolders.Count; $i++) {
    $j = $i
    while ($ArrayOfFolders[$j].Fullname.Length -gt $ArrayOfFolders[$j - 1].Fullname.Length) {
        $Temp = $ArrayOfFolders[$j - 1]
        $ArrayOfFolders[$j - 1] = $ArrayOfFolders[$j]
        $ArrayOfFolders[$j] = $Temp
        $j--
        if ($j -eq 0) {break}
    }
    }
    return $ArrayOfFolders
}

function Process-Length {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        [System.Collections.ArrayList]$collection
    )

    foreach ($item in $collection) {
        $Global:ObjectsToRename += $item
    }
    try {
        foreach ($item in $Global:ObjectsToRename) {
        #Write-Warning "Working on $($item.fullname)"
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Working on $($item.fullname)")})
        Write-Log -Message "Working on $($item.fullname)"
        Rename-Object -Object $item }
    } 
    catch {
        $Exception = $_.Exception
        if ($Exception -like "*Collection was modified*") {
         $Global:ObjectsToRename.clear()
         if ($Global:RenamedObj.Attributes -eq "Directory") {
         Process-Directories}
    }
    }
    
}

function Rename-Object {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        $Object
    )

if ($($Object.name.length) -le (5 + $global:count.toString().length + $($Object.Extension.Length))) {
    $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("WARNING: File name less than allowed....")})
    Write-Log -Level Warn -Message "WARNING: File name less than allowed...."
    if ($Object.Attributes -eq "Directory") {
    $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Renaming parent folder $($Object.Parent.Name)")})
    Write-Log -Message "Renaming parent folder $($Object.Parent.Name)"
    Rename-Object $($Object.parent)
    } else {
    $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Renaming parent folder $($Object.Directory.Name)")})
    Write-Log -Message "Renaming parent folder $($Object.Directory.Name)"
    Rename-Object $Object.Directory}
    #return
} else {
try {
    $Fullname = $Object.fullname
    $Newname = $Object.name.remove(5) + $global:count + $Object.Extension
    $NewFilePath = ""
    if($Object.Attributes -eq "Directory") {
        $Parent = $($Object.parent.fullname)
        $NewFilePath = "$Parent" + "\" + $Newname}
    else {
        $NewFilePath = "$($Object.Directory.Fullname)" + "\" + $Newname}
    Rename-Item -LiteralPath $Fullname -NewName $Newname -ErrorAction Stop -Force
    $global:count++
    $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Object $($Object.name) renamed to $Newname`nnew path is: $NewFilePath")})
    Write-Log -Message "Object $($Object.name) renamed to $Newname`nNew path is: $NewFilePath"
    $Global:RenamedObj = Get-ChildItem -LiteralPath $NewFilePath
    if (isFile $Global:RenamedObj) {$Global:TotalFiles++}
    else {$Global:TotalDirectories++}
}
catch {
    $Except = $_.Exception
    if ($Except -like "*не существует*" -or $Except -like "*does not exist*") {
        if ($Object.Attributes -eq "Directory") {Rename-Object -Object $($Object.Parent) -ErrorAction SilentlyContinue
        } elseif ($Object.Attributes -eq "Archive") {Rename-Object -Object $($Object.Directory) -ErrorAction SilentlyContinue}
    } elseif ($Except -like "*Cannot create a file when that file already exists.*") {
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Object already exist. Increase global count by 1....")})
        Write-Log -Message "Object already exist. Increase global count by 1...."
        $global:count++
        Rename-Object -Object $Object}
    else {
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("$Except")})
        Write-Log -Level Error -Message "$Except"}
}
}
}

function Get-Directories {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        $PathToDirectories
    )

    Get-ChildItem -Path $PathToDirectories -Recurse -Directory | Select -property * | where {$_.Fullname.Length -ge $($syncHash.MaxPathLength)} -ErrorAction SilentlyContinue
}

function Get-Files {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        $PathToFiles
    )
    Get-ChildItem -Path $PathToFiles -Recurse -File | Select -property * | where {$_.Fullname.Length -ge $($syncHash.MaxPathLength) -and $_.Extension -notlike ".db"} -ErrorAction SilentlyContinue
}

function Process-Directories {
    if($Global:ObjectsToRename.count -ne 0) {$Global:ObjectsToRename.Clear()}
    $Directories = Get-Directories -PathToDirectories $Global:Path
    if($Directories.count -eq 0) {
       $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("There are no directories to rename for $($syncHash.SelectedItem)")})
       Write-Log -Message "There are no directories to rename for $($syncHash.SelectedItem)"
    } 
    else {
    [System.Collections.ArrayList]$sortedFolder = Sort-Object -ArrayOfFolders $Directories
    $sortedFolder.RemoveAt(0)
    Process-Length $Directories}
}

function Process-Files {
    if($Global:ObjectsToRename.count -ne 0) {$Global:ObjectsToRename.Clear()}
    $Files = Get-Files -PathToFiles $Global:Path
    if($Files.count -eq 0) {
         $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("There are no files to rename for $($syncHash.SelectedItem)")})
         Write-Log -Message "There are no files to rename for $($syncHash.SelectedItem)"
         }
    else {
    [System.Collections.ArrayList]$sortedFiles = Sort-Object -ArrayOfFolders $Files
    $sortedFiles.RemoveAt(0)
    Process-Length $Files}
}
function isFile {
    param (
        [Parameter(Mandatory=$true,Position=0)]
        $inputObj
    )
    if($inputObj.Attributes -eq "Archive") {
        return $true
    }
    else {return $false}
}
#$syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("$($syncHash.MaxPathLength) is finished and selected item was $($syncHash.SelectedItem)")})
function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path="$($syncHash.PathToModule)" + "\Renamed_Objects_For_" + "$($syncHash.SelectedItem)" + ".log",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
}

