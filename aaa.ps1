# Load the XML file
$xmlPath = 'D:\Git\raandreeSamplerTest1\gpreport.xml'
$xml = [xml](Get-Content $xmlPath)

#$xmlNameSpaceList = $xml.SelectNodes("//namespace::*[not(. = ../../namespace::*)]")
#$xmlNameSpaceManager = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)

#foreach ($nsNode in $xmlNameSpaceList)
#{
#    $xmlNameSpaceManager.AddNamespace($nsNode.LocalName, $nsNode.Value)
#}

$searchProperty = 'Name' #'SystemAccessPolicyName' #'Name'
$searchValue = 'camera' #'camera'

$elements = $xml.SelectNodes("//q1:$searchProperty", $ns) |
    Where-Object { $_.InnerText -like "*$searchValue*" }

# Display the results
Write-Host "Found $($elements.Count) elements containing '$searchValue':" -ForegroundColor Green
foreach ($element in $elements)
{
    Write-Host "- $($element.InnerText)"

    # Optionally show the parent policy state for context
    $policy = $element.ParentNode
    if ($policy.Name -eq 'Policy')
    {
        Write-Host "  State: $($policy.SelectSingleNode('q1:State', $ns).InnerText)"
    }
    Write-Host ''

    [PSCustomObject]@{
        Naame     = $policy.Name
        State     = $policy.SelectSingleNode('q1:State', $ns).InnerText
        Explain   = $policy.SelectSingleNode('q1:Explain', $ns).InnerText
        Supported = $policy.SelectSingleNode('q1:Supported', $ns).InnerText
        Categor   = $policy.SelectSingleNode('q1:Category', $ns).InnerText
    }
}
