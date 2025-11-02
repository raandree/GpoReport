@{
    # Required for Sampler framework
    InvokeBuild                 = 'latest'
    PSScriptAnalyzer            = 'latest'
    Pester                      = 'latest'
    Sampler                     = 'latest'
    'Sampler.GitHubTasks'       = 'latest'
    MarkdownLinkCheck           = 'latest'
    ModuleBuilder               = 'latest'
    ChangelogManagement         = 'latest'
    
    # PSDependOptions for PSDepend when used
    PSDependOptions             = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }
}
