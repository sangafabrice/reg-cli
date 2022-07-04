---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# New-RegCliUpdate

## SYNOPSIS
Loads a new installation/update module

## SYNTAX

```
New-RegCliUpdate [-Path] <String> [-SaveTo] <String> [-Version] <String> [-Description] <String>
 [<CommonParameters>]
```

## DESCRIPTION
The New-RegCliUpdate function loads a module of helper functions for non-specific software update/installation tasks. 

## EXAMPLES

### Example 1
```powershell
PS C:\> New-RegCliUpdate 'C:\ProgramData\Brave\brave.exe' $PWD '103.1.40.109' 'Brave Installer'
```

Creates a Brave browser installation or upadate.

## PARAMETERS

### -Description
File description of the binary file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Path to the binary file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SaveTo
Path to the downloaded installer directory.

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

### -Version
Version of the software to install.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### System.Management.Automation.PSModuleInfo

## NOTES

## RELATED LINKS
