---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Get-ExecutableType

## SYNOPSIS
Gets the machine type of a binary file.

## SYNTAX

```
Get-ExecutableType [-Path] <String> [<CommonParameters>]
```

## DESCRIPTION
The Get-ExecutableType function gets the machine type of a binary file. When the file does not exist, the function returns the architecture of the Operating System.

## EXAMPLES

### Example 1
```powershell
PS C:\> [Environment]::Is64BitOperatingSystem
True

PS C:\> Get-ExecutableType 'C:\GoogleChrome\chrome.exe'
x86

PS C:\> Remove-Item 'C:\GoogleChrome\chrome.exe'
PS C:\> Get-ExecutableType 'C:\GoogleChrome\chrome.exe'
x64
```

Get the machine type of chrome application.

## PARAMETERS

### -Path
Path to the binary file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

## OUTPUTS

### MachineType

## NOTES

## RELATED LINKS
