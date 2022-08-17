$DevDependencies = @{
    ProgramName = 'Blisk'
    Description = 'The script installs or updates Blisk browser on Windows.'
    Guid = '0f0234b8-2357-4909-a0b2-094a02e96be4'
    IconUri = 'https://rawcdn.githack.com/sangafabrice/reg-cli/58d15da2c7da327f3561e3c86884582d7e0db854/icon.png'
    Tags = @('blisk','chromium','update','browser')
    RemoteRepo = (git ls-remote --get-url) -replace '\.git$'
}