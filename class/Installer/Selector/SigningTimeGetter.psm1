"$(Invoke-WebRequest 'https://gist.githubusercontent.com/sangafabrice/9f866c5035c8d74201b8a76406d2100e/raw/35d9aea933b0e0a27cc74625fa612f56e7a81ca5/SigningTimeGetter.psm1')" |
Out-File $PSCommandPath
Import-Module $PSCommandPath -Force