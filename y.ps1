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

$searchValue = ''
$xmlPath = 'D:\Git\GpoReport\reports\t2.xml'
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
    $extension.Extension.ChildNodes
}
$elements += foreach ($extension in $xml.GPO.User.ExtensionData) {
    $extension.Extension.ChildNodes
}

if ($searchValue) {
    $elements = $elements | Where-Object { $_.OuterXml -like "*$searchValue*" }
}

#$possibleParentNodeTypes = 'Policy', 'UserRightsAssignment', 'SecurityOptions'
Write-Host "Found $($elements.Count) elements containing '$searchValue':" -ForegroundColor Green
foreach ($element in $elements) {
    Write-Host "- $element"

    $elementTypeName = $element.psobject.TypeNames[0].Split('#')[-1]

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
