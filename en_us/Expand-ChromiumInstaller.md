---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Expand-ChromiumInstaller

## SYNOPSIS
Extracts files from a specified chromium installer (exe) file.

## SYNTAX

```
Expand-ChromiumInstaller [-Path] <String> [-ApplicationPath] <String> [<CommonParameters>]
```

## DESCRIPTION
The Expand-ChromiumInstaller extracts files from a specified executable chromium installer file to the directory in which the application is located (ApplicationPath).

## EXAMPLES

### Example 1
```powershell
PS C:\> Expand-ChromiumInstaller 'C:\chrome_installer.exe' 'C:\ProgramData\GoogleChrome\chrome.exe'
```

This command installs Google Chrome to 'C:\ProgramData\GoogleChrome'.

## PARAMETERS

### -ApplicationPath
Path to chromium application executable.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to chromium installer.

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

### System.Void

## NOTES

## RELATED LINKS
