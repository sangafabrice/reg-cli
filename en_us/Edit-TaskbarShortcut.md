---
external help file: RegCli-help.xml
Module Name: RegCli
online version:
schema: 2.0.0
---

# Edit-TaskbarShortcut

## SYNOPSIS
Reset target path of an existing taskbar link

## SYNTAX

```
Edit-TaskbarShortcut [-Path] <String> [<CommonParameters>]
```

## DESCRIPTION

## EXAMPLES

### Example 1
```powershell
PS C:\> $WsShell = New-Object -ComObject 'Wscript.Shell'
PS C:\> $MSEdgeShortcut = "${Env:APPDATA}\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk"
PS C:\> $WsShell.CreateShortcut($MSEdgeShortcut).TargetPath
C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
PS C:\> Edit-TaskbarShortcut "C:\MSEdge\msedge.exe"
PS C:\> $WsShell.CreateShortcut($MSEdgeShortcut).TargetPath
C:\MSEdge\msedge.exe
```

{{ Add example description here }}

## PARAMETERS

### -Path
Path to the targeted executable.

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
