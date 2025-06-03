# Load the XML file
$xmlPath = 'D:\Git\raandreeSamplerTest1\gpo2.xml'
$xml = [xml](Get-Content $xmlPath)

# Register the namespace used in the XML
$xmlNameSpaceList = $xml.SelectNodes('//namespace::*[not(. = ../../namespace::*)]')
$xmlNameSpaceManager = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)

foreach ($nsNode in $xmlNameSpaceList)
{
    try
    {
        $xmlNameSpaceManager.AddNamespace($nsNode.LocalName, $nsNode.Value)
    }
    catch
    {
        Write-Verbose "Error adding namespace: $($_.Exception.Message)"
    }
}

$relevantNamespaces = $xmlNameSpaceManager -like 'q*'

$searchProperty = 'Name'
$searchValue = ''

$elements = foreach ($relevantNamespace in $relevantNamespaces)
{
    $xml.SelectNodes("//$($relevantNamespace):$($searchProperty)", $xmlNameSpaceManager)
}

if ($searchValue)
{
    $elements = $elements | Where-Object { $_.InnerText -like "*$searchValue*" }
}

$possibleParentNodeTypes = 'Policy', 'UserRightsAssignment', 'SecurityOptions'
Write-Host "Found $($elements.Count) elements containing '$searchValue':" -ForegroundColor Green
foreach ($element in $elements)
{
    Write-Host "- $($element.InnerText)"

    $parentNode = $element.ParentNode

    $elementTypeName = $parentNode.psobject.TypeNames[0].Split('#')[-1]
    if ($elementTypeName -notin $possibleParentNodeTypes)
    {
        continue
    }

    $properties = @{}
    foreach ($property in ($parentNode | Get-Member -MemberType Property))
    {
        $properties[$property.Name] = $parentNode.($property.Name)
    }
    [PSCustomObject]$properties

    <#
    switch ($elementTypeName)
    {
        { $_ -eq 'Policy' }
        {
            [PSCustomObject]@{
                Name      = $parentNode.Name
                State     = $parentNode.State
                Explain   = $parentNode.Explain
                Supported = $parentNode.Supported
                Category  = $parentNode.Category
                Comment   = $parentNode.Comment
            }
        }
        { $_ -eq 'UserRightsAssignment' }
        {
            [PSCustomObject]@{
                Name      = $parentNode.Name
                State     = $parentNode.State
                Explain   = $parentNode.Explain
                Supported = $parentNode.Supported
                Comment   = $parentNode.Comment
            }
        }
        { $_ -eq 'SecurityOption' }
        {
            [PSCustomObject]@{
                Name      = $parentNode.Name
                State     = $parentNode.State
                Explain   = $parentNode.Explain
                Supported = $parentNode.Supported
                Category  = $parentNode.Category
            }
        }
    }
    #>
}
