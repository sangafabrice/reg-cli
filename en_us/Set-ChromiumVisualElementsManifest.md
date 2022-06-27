---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Set-ChromiumVisualElementsManifest

## SYNOPSIS
Sets the content of the VisualElementsManifest.xml file.

## SYNTAX

```
Set-ChromiumVisualElementsManifest [-Path] <String> [[-BackgroundColor] <String>] [<CommonParameters>]
```

## DESCRIPTION

## EXAMPLES

### Example 1
```powershell
PS C:\> Set-ChromiumVisualElementsManifest 'C:\Secure\AvastBrowser.VisualElementsManifest.xml' '#2D364C'
```

## PARAMETERS

### -BackgroundColor
Hexadecimal color code.

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
Path to VisualElementsManifest.xml

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
