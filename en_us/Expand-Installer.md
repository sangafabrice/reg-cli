---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Expand-Installer

## SYNOPSIS
Extract files from a specified self-extracting executable

## SYNTAX

```
Expand-Installer [-Path] <String> [[-Destination] <String>] [<CommonParameters>]
```

## DESCRIPTION

## EXAMPLES

### Example 1
```powershell
PS C:\> Expand-ChromiumInstaller 'C:\chrome_installer.exe' 'C:\chrome_installer'
```

This command unzip chrome installer.

## PARAMETERS

### -Destination
Path to destination directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to installer.

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
