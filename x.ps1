$xml = Get-Content .\gpreport.xml -Raw
$xml = [xml]$xml

$namespace = @{
    ns  = 'http://www.microsoft.com/GroupPolicy/Settings'
    xsi = 'http://www.w3.org/2001/XMLSchema-instance'
    xsd = 'http://www.w3.org/2001/XMLSchema'
    q1  = 'http://www.microsoft.com/GroupPolicy/Settings/Security'
}

$nsm = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
foreach ($key in $namespace.Keys) {
    $nsm.AddNamespace($key, $namespace[$key])
}

$xml.SelectNodes('//Computer', $nsm)

$xpath = '//q1:SecurityOptions/q1:Display/q1:Name'
$xpath = '//q1:SecurityOptions/q1:Display/q1:Name'
$result = (Select-Xml -Path D:\Git\raandreeSamplerTest1\gpreport.xml -XPath $xpath -Namespace $namespace).Node.InnerText
$result
