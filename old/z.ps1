# Define the path to the XML file
$xmlPath = 'D:\Git\raandreeSamplerTest1\gpreport.xml'

# Load the XML file
$xml = [xml](Get-Content -Path $xmlPath)

# Function to find elements with a specific namespace
function Find-ElementsWithNamespace
{
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlNode]$Node,

        [Parameter(Mandatory = $true)]
        [string]$Namespace,

        [System.Collections.ArrayList]$Results = (New-Object System.Collections.ArrayList)
    )

    # Check attributes for namespace definitions
    if ($Node.Attributes)
    {
        foreach ($attr in $Node.Attributes)
        {
            if (($attr.Name -like 'xmlns:*' -or $attr.Name -eq 'xmlns') -and $attr.Value -eq $Namespace)
            {
                if (-not ($Results -contains $Node))
                {
                    $null = $Results.Add($Node)
                }
            }
        }
    }

    # Check all child nodes
    if ($Node.HasChildNodes)
    {
        foreach ($child in $Node.ChildNodes)
        {
            Find-ElementsWithNamespace -Node $child -Namespace $Namespace -Results $Results
        }
    }

    return $Results
}

# Find elements with the specified namespace
$targetNamespace = 'http://www.microsoft.com/GroupPolicy/Settings/Registry'
$elementsWithNamespace = Find-ElementsWithNamespace -Node $xml -Namespace $targetNamespace

# Display results
Write-Host "Found $($elementsWithNamespace.Count) elements using the namespace '$targetNamespace':" -ForegroundColor Green

foreach ($element in $elementsWithNamespace)
{
    Write-Host "`nElement: $($element.Name)" -ForegroundColor Yellow
    Write-Host "Path: $($element.ParentNode.Name)/$($element.Name)"

    # Show the namespace declaration attribute
    $nsAttr = $element.Attributes | Where-Object {
        ($_.Name -like 'xmlns:*' -or $_.Name -eq 'xmlns') -and $_.Value -eq $targetNamespace
    }

    if ($nsAttr)
    {
        Write-Host "Namespace declaration: $($nsAttr.Name)='$($nsAttr.Value)'"
    }

    # Show the first few child elements to provide context
    if ($element.HasChildNodes)
    {
        Write-Host 'First child elements:'
        $childCount = 0
        foreach ($child in $element.ChildNodes)
        {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element)
            {
                Write-Host "  - $($child.Name)"
                $childCount++
                if ($childCount -ge 3)
                {
                    break
                }
            }
        }
    }
}
