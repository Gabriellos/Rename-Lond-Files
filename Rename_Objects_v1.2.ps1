Add-Type -AssemblyName PresentationFramework
[xml]$xaml = @"
<Window
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Rename Objects" Height="451" Width="1263">
<Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="34*"></RowDefinition>
            <RowDefinition Height="401*"></RowDefinition>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80*"></ColumnDefinition>
            <ColumnDefinition Width="341*"></ColumnDefinition>
        </Grid.ColumnDefinitions>
        <ListBox x:Name="ListBox" Grid.Row="1" FontSize="18"/>
        <Label Content="        User Name" HorizontalAlignment="Center" VerticalAlignment="Center" Width="240" Grid.Row="0" FontSize="18" FontFamily="Arial Black"/>
        <ListBox x:Name="ResultTextBox" Grid.Column="1" Grid.Row="1" FontSize="18" />  
        <TextBox x:Name="MaxPathLength" Grid.Column="1" HorizontalAlignment="Left" Margin="316,0,0,0" TextWrapping="Wrap" VerticalAlignment="center" Width="65" Height="32" FontSize="18"/>
        <Label Content="Enter maximum allowed path length:" Grid.Column="1" HorizontalAlignment="Left" Margin="10,0,0,0" VerticalAlignment="Center" Height="32" Width="306" FontSize="18"/>
        <Button x:Name="StartButton" Content="Start" Grid.Column="1" HorizontalAlignment="left" Margin="879,0,0,0" VerticalAlignment="Center" Height="32" Width="134" FontSize="20"/>
    </Grid>
</Window>
"@
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load($reader)

#Connect to controls

$ListBox = $Window.FindName('ListBox')
$InputBox = $Window.FindName('MaxPathLength')
$StartBtn = $Window.FindName('StartButton')
$ResultOutput = $Window.FindName('ResultTextBox')


$Global:Folders = Get-ChildItem 'F:\home\' -Directory | select name -ExpandProperty name
$ListBox.ItemsSource = $Folders
$syncHash = [hashtable]::Synchronized(@{})
$syncHash.InputBox = $InputBox
$syncHash.result = $ResultOutput
$syncHash.PathToModule = $PSScriptRoot

#Add Click Event

$StartBtn.Add_Click({

$ResultOutput.Items.Clear()

$syncHash.MaxPathLength = $syncHash.InputBox.Text
$syncHash.SelectedItem = $ListBox.SelectedItem

$runspace =[runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable('syncHash',$syncHash)
$powerShell = [powershell]::Create()
$powerShell.runspace = $runspace

$powerShell.AddScript({
        #Wait-Debugger
        [int]$global:count = 1
        [int]$Global:TotalDirectories = 0
        [int]$Global:TotalFiles = 0
        [System.Collections.ArrayList]$Global:ObjectsToRename = @()
        $Module = "$($syncHash.PathToModule)" + "\" + "Rename_Object_Module.psm1"
        Import-Module $Module
        [string]$Global:Path = Get-WorkingHomeDirectory -Username $syncHash.SelectedItem
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Checking directories...")})
        Process-Directories
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Checking files...")})
        Process-Files
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Total renamed directories: $Global:TotalDirectories")})
        $syncHash.result.Dispatcher.Invoke([action]{$syncHash.result.Items.Add("Total renamed files: $Global:TotalFiles")})
    })

    $AsyncObject = $powerShell.BeginInvoke()    
})

$Window.ShowDialog() | Out-Null