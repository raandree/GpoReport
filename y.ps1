function ConvertTo-GpoObject {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Object
    )

    $result = [ordered]@{}
    $properties = $Object | Get-Member -MemberType Property
    foreach ($property in $properties) {
        if ($property.Definition -like '*[[]]*') {
            
            foreach ($item in $element.($property.Name)) {
                if ($item -is [System.Xml.XmlElement]) {
                    $result[$property.Name] += @(ConvertTo-GpoObject -Object $item)
                }
                else {
                    $result[$property.Name] += @($item)
                }
            }
        }
        else {
            if ($property.Definition -like 'System.Xml.XmlElement*') {
                $result.Add($property.Name, (ConvertTo-GpoObject -Object $Object.($property.Name)))
            }
            else {
                $result.Add($property.Name, $Object.($property.Name))
            }
        }
    }
    [PSCustomObject]$result
}

function xx {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'XmlElement')]
        [System.Xml.XmlElement]
        $XmlElement,

        [Parameter(Mandatory = $true, ParameterSetName = 'ObjectArray')]
        [object[]]
        $Objects
    )

    if ($pscmdlet.ParameterSetName -eq 'ObjectArray') {
        foreach ($XmlElement in $Objects) {
            xx -XmlElement $XmlElement
        }
    }
    else {
        foreach ($entry in $XmlElement) {
            $data = @{}
            $properties = $entry | Get-Member -MemberType Property 
            foreach ($property in $properties) {
                $data.Add($property.Name, $entry.($property.Name))
            }
            [PSCustomObject]$data
        }
    }
}

$searchValue = ''
$xmlPath = 'D:\Git\GpoReport\reports\AllSettings1.xml'
$xml = [xml](Get-Content $xmlPath)
$propertiesToSkip = 'Explain'

# Register the namespace used in the XML
$xmlNameSpaceNodes = $xml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]')
$xmlNameSpaceNodes = $xmlNameSpaceNodes | Sort-Object -Property LocalName -Unique
$xmlNameSpaceManager = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
$xmlNameSpaces = @{}

foreach ($nsNode in $xmlNameSpaceNodes) {
    try {
        if ($nsNode.LocalName -like 'q*') {            
            $xmlNameSpaces[$nsNode.LocalName] = $nsNode.Value
        }
        $xmlNameSpaceManager.AddNamespace($nsNode.LocalName, $nsNode.Value)
    }
    catch {
        Write-Verbose "Error adding namespace: $($_.Exception.Message)"
    }
}

#$elements = foreach ($xmlNamespace in $xmlNameSpaces.GetEnumerator()) {
#    $xml.SelectNodes("//*[namespace-uri() = '$($xmlNamespace.Value)']", $xmlNameSpaceManager) |
#        ForEach-Object {
#            if( -not ($_.ChildNodes.Count -eq 1 -and $_.ChildNodes[0].Name -eq '#text') )
#            {
#                $_
#            }
#            else
#            {
#                Write-Host 'x'
#            }
#        }
#}

$elements = @()
$elements += foreach ($extension in $xml.GPO.Computer.ExtensionData) {
    $extensionType = $extension.Extension.type.Split(':')[1]

    switch ($extensionType) {
        'RegistrySettings' {
            foreach ($policy in $extension.Extension.Policy) {
                [PSCustomObject]@{
                    Name      = $policy.Name
                    State     = $policy.State
                    Supported = $policy.Supported
                    Category  = $policy.Category
                }
            }
        }
        'FoldersSettings' {
            Write-Host "Processing 'FoldersSettings' extension, found $($nodes.Count) folders."
            [PSCustomObject]@{
                FolderSettings = $extension.Extension.ChildNodes[0].Folder
            }
        }
        'SecuritySettings' {
            Write-Host "Processing 'SecuritySettings' extension, found $($nodes.Count) security settings."

            foreach ($accountPolicy in $extension.Extension.Account) {
                $data = @{}
                $properties = $accountPolicy | Get-Member -MemberType Property 
                foreach ($property in $properties) {
                    $data.Add($property.Name, $accountPolicy.($property.Name))
                }
                [PSCustomObject]$data
            }

            foreach ($accountPolicy in $extension.Extension.Audit) {
                $data = @{}
                $properties = $accountPolicy | Get-Member -MemberType Property 
                foreach ($property in $properties) {
                    $data.Add($property.Name, $accountPolicy.($property.Name))
                }
                [PSCustomObject]$data
            }

            [PSCustomObject]@{
                SecuritySettings = [PSCustomObject]@{
                    UserRightsAssignment = $extension.Extension.UserRightsAssignment
                    SecurityOptions      = $extension.Extension.SecurityOptions
                    Audit                = $extension.Extension.Audit
                }
            }
        }
    }
}


#$possibleParentNodeTypes = 'Policy', 'UserRightsAssignment', 'SecurityOptions'
Write-Host "Found $($elements.Count) elements containing '$searchValue':" -ForegroundColor Green
foreach ($element in $elements) {
    if ($searchValue -and $element.OuterXml -notlike "*$searchValue*") {
        continue
    }
    Write-Host "- $element"

    $result = [ordered]@{}
    foreach ($property in ($element | Get-Member -MemberType Property)) {
        if ($propertiesToSkip -contains $property.Name) {
            continue
        }

        if ($property.Definition -like '*[[]]*') {
            
            foreach ($item in $element.($property.Name)) {
                if ($item -is [System.Xml.XmlElement]) {
                    $result[$property.Name] += @(ConvertTo-GpoObject -Object $item)
                }
                else {
                    $result[$property.Name] += @($item)
                }
            }
        }
        else {
            if ($property.Definition -like 'System.Xml.XmlElement*') {
                $result[$property.Name] = ConvertTo-GpoObject -Object $element.($property.Name)
            }
            else {
                $result[$property.Name] = $element.($property.Name)
            }
        }
    }
    [PSCustomObject]$result

}
