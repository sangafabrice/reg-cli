On Error Resume Next
Set Named = WScript.Arguments.Named
Set MSIView = CreateObject("WindowsInstaller.Installer")._
    OpenDatabase(Named("Path"), 0)._
    OpenView("SELECT Value FROM Property WHERE Property='" & Named("Property") & "'")
MSIView.Execute()
WScript.Echo MSIView.Fetch().StringData(1)
MSIView.Close
Set MSIView = Nothing