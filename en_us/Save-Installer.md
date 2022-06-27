---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Save-Installer

## SYNOPSIS
Downloads a specified installer.

## SYNTAX

```
Save-Installer [-Url] <Uri> [<CommonParameters>]
```

## DESCRIPTION
The Save-Installer function downloads a specified installer to the %TEMP% directory and appends timestamp to the installer base name. The URL must be secured.

## EXAMPLES

### Example 1
```powershell
PS C:\> Save-Installer 'https://github.com/ytdl-org/youtube-dl/releases/download/2021.12.17/youtube-dl.exe'
```

The command downloads youtube-dl.exe.

## PARAMETERS

### -Url
Url of the installer to download.

```yaml
Type: Uri
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

### System.Uri

## OUTPUTS

### System.String

## NOTES

## RELATED LINKS
