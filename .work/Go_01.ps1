
# set searchstring
#$SearchString = "Remove Libraries"
$SearchString = "Remote "

# select GPOs for searching searchstring
$allGPOs = get-gpo -all | Where-Object {$_.DisplayName -like "Test*"} | Sort-Object -Property DisplayName

# start searchstring in each selected GPO
$allresults = foreach ($GPO in $allGPOs){
    # create XML Object
    $XMLGPOObject = Get-GPOReport -name $GPO.DisplayName -ReportType Xml
    # start search in selected GPO
    Search-GPMCReports -XmlContent $XMLGPOObject -SearchString $SearchString
}

#region ----[Start outout]-------------------------------------------------------------------------
function New-Report ($PageTitle, $SearchString, $TableOne, $TableOfResults, $ResultCount) {

    $DateCreate = (get-Date).ToString("dd.MM.yyyy HH:mm:ss")

    $HTML_Document = @"
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>$PageTitle</title>
        <style type="text/css">
            /* default body configuration */
            body {
                background: white; /* #ffffff */
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
                text-align: left; 
                font-family: "Segoe UI", Verdana, sans-serif; 
                font-style: normal; 
            }
            
            /* Table in the head section if the web page  */
            table.HeadLine {
                background: #ffffff;
                width: 100%; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
                border-collapse: collapse; /* no cell spacing */
                /*border: 0px solid black;*/
                text-align: left; 
                font-family: "Segoe UI", Verdana, sans-serif; 
            }
            tr.HeadLine {
                height: 38px;
                border-collapse: collapse; /* no cell spacing */
            }
            th.HeadLine {
                color: #ffffff; 
                background: #0078d4;
                border-collapse: collapse; /* no cell spacing */
                line-height: 30px; 
                /* vertical-align: bottom; */
                /* padding: 6px 5px; */
                /* text-align: left; */
                /* font-size: 18px; */
            }
            td.HeadLine { 
                color: #ffffff; 
                background: #004b76;
                border-collapse: collapse; /* no cell spacing */
                /* padding: 6px 5px; */
                line-height: 30px;
                /* text-align: left; */
                /* font-size: 12px; */
                vertical-align: bottom;
            }
            h1.HeadLine {
                margin-left: 5px;
                color: #ffffff;
                font-size: 16px;
                font-weight: lighter;
            }
            h2.HeadLine {
                margin-left: 5px;
                color: #ffffff;
                font-size: 14px;
                font-weight: lighter;
            }

            h1 { 
                text-align: left; 
                font-family: Segoe UI, Verdana, sans-serif;
                font-size: 20px;
                color: #ffffff;
                background: #0078d4;
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            h2 {
                text-align: left; 
                font-family: Segoe UI, Verdana, sans-serif; 
                font-style: normal; 
                font-size: 14px;
                color: #ffffff;
                /* background: #004b76;*/
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }

            table { 
                background: #ffffff;
                border-collapse: collapse;
                align: left; 
                width: 100%; 
                font-family: Segoe UI, Verdana, sans-serif; 
                font-style: normal; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            tr {
            }
            th { 
                /* background: #0078d4; */
                background: #004b76;
                color: #ffffff; 
                width: 50%; 
                text-align: left;
                padding: 5px 10px; 
                font-size: 14px;
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            td { 
                color: #000000; 
                width: 50%; 
                vertical-align: top; 
                padding: 5px 20px;  
                text-align: left;
                font-size: 12px; 
                margin: 0;
                    margin-top: 0px;
                    margin-right: 0px;
                    margin-bottom: 0px;
                    margin-left: 0px;
            }
            tr { background: #ffffff; }
            tr:nth-child(even) { background: #bec5C933; }
            tr:nth-child(odd) { background: #b8d1f3; }

            p { font-family: Segoe UI, Verdana, sans-serif; }

        </style>
    </head>
    <body>
    	<table Class="HeadLine">
            <tr><th Class="HeadLine"><h1 Class="HeadLine">$PageTitle</h1></th><th Class="HeadLine"><h2 Class="HeadLine">$SearchString</h2></th></td></tr>
		    <tr><td Class="HeadLine"><h2 Class="HeadLine">Found entries:</h2></td><td class="HeadLine"><h2 Class="HeadLine">$ResultCount</h2></td></tr>
        </table>
        <br>
        $TableOfResults
        <table Class="HeadLine">
            <tr Class="HeadLine"><td Class="HeadLine"></td><td class="HeadLine"></td></tr>
            <tr><th Class="HeadLine"><h1 Class="HeadLine">Automatische generiert auf: $($env:Computername)</h1></th><th Class="HeadLine"><h2 Class="HeadLine">am: $DateCreate</h2></th></td></tr>
        </table>
    </body>
</html>
"@
    # create base statistic
    $HTML_Document | Out-File -filepath "C:\Temp\test.html" -force
    Start-Process "msedge.exe" -ArgumentList "c:\temp\test.html"
}
#endregion -[END outout]---------------------------------------------------------------------------

$TableOfResults = @()
foreach ($result in $allResults) {

    #region ----[Start create table for the results]-----------------------------------------------
    $GPO = Get-GPO -Name $result.GPOName
    $CreationTime = ($GPO.CreationTime).ToString("dd.MM.yyyy HH:mm:ss")

    $ModificationTime = ($GPO.ModificationTime).ToString("dd.MM.yyyy HH:mm:ss")
    $TableOfResults += "<table>"
    
    #region ----[Start GPO information]------------------------------------------------------------
    $TableOfResults += "<tr><th>GPO name:</th><th>$($GPO.DisplayName)</th></tr>"
    $GPOdescription = $GPO.Description -replace (";","<br>")
    $TableOfResults += "<tr><td><b>GPO description: </b></td><td>$GPOdescription</td></tr>"
    $TableOfResults += "<tr><td><b>GPO created: </b></td><td>$CreationTime</td></tr>"
    $TableOfResults += "<tr><td><b>GPO modified: </b></td><td>$ModificationTime</td></tr>"
    #endregion -[END GPO information]--------------------------------------------------------------
    
    $TableOfResults += "<tr><td><u>Setting Details:</u></td><td></td></tr>"
    # add setting path
    $TableOfResults += "<tr><td><b>Setting Path:</b></td><td>$($Result.Section) > $($result.CategoryPath)</td></tr>"
    if ($result.XmlNode.ParsedXml.Name){$TableOfResults += "<tr><td><b>Policy Name:</b></td><td>$($result.XmlNode.ParsedXml.Name)</td></tr>"}
    

    #region ----[Start localsecurity settings ...]-------------------------------------------------
    $Member = ($result.XmlNode.parsedXml.Member.Name.Text) -join "<br>"
    if ($result.XmlNode.parsedXml.Member){$TableOfResults += "<tr><td><b>Policy Member:</b></td><td>$Member</td></tr>"}

    
    #region ----[Start certifications]-------------------------------------------------------------
    if (($result.XmlNode.ElementName) -eq "IssuedTo"){
        $TableOfResults += "<tr><td><b>Certificate Name:</b></td><td>$($result.XmlNode.ParsedXml.Text)</td></tr>"
        $CertificationTyp = ($result.XmlNode.ParentHierarchy)[(($result.XmlNode.ParentHierarchy).count) -1]
        $TableOfResults += "<tr><td><b>Certification Type:</b></td><td>$CertificationTyp</td></tr>"
    }
    #endregion -[END certifications]---------------------------------------------------------------
    
    #endregion -[END localsecurity settings ...]---------------------------------------------------
    

    #region ----[Start Policy settings]------------------------------------------------------------
    if ($result.XmlNode.ElementName -eq "Policy"){
        #if ($result.XmlNode.ParsedXml.Name){$TableOfResults += "<tr><td><b>Policy Name::</b></td><td>$($result.XmlNode.ParsedXml.Name)</td></tr>"}
        if ($result.XmlNode.ParsedXml.State){$TableOfResults += "<tr><td><b>State:</b></td><td>$($result.XmlNode.ParsedXml.State)</td></tr>"}

        # if policy contains listbox
        if ($result.XmlNode.ParsedXml.ListBox){
            $ListBoxString = ([System.String]::join("<br>", ($result.XmlNode.ParsedXml.ListBox.Value.Element.Data))).ToString()
            $TableOfResults += "<tr><td><b>ListBox:</b></td><td>$($ListBoxString)</td></tr>"
        }
    }
    #endregion -[END Policy settings]--------------------------------------------------------------


    #region ----[Start GPP settings]---------------------------------------------------------------
    if ($result.xmlnode.ParsedXml._name){$TableOfResults += "<tr><td><b>Name:</b></td><td>$($result.xmlnode.ParsedXml._name)</td></tr>"}

    #region ----[Start File settings]--------------------------------------------------------------
    if ($result.XmlNode.ParentHierarchy -contains "FilesSettings"){
        #$TableOfResults += "<tr><td><b>TEST - Type:</b></td><td>$($result.XmlNode.ElementName)</td></tr>"
        $TableOfResults += "<tr><td><b>Source file:</b></td><td>! ! ! Fehlt noch ! ! !</td></tr>"
        $TableOfResults += "<tr><td><b>Targe File:</b></td><td>$($result.xmlnode.ParsedXml.Properties._targetPath)</td></tr>"
    }
    #endregion -[END File]- settings---------------------------------------------------------------

    #region ----[Start Folder settings]------------------------------------------------------------
    if ($result.XmlNode.ParentHierarchy -contains "Folder"){
        $TableOfResults += "<tr><td><b>SettingName(Folder):</b></td><td>$($result.SettingName)</td></tr>"
        if ($result.xmlnode.ParsedXml._Path){$TableOfResults += "<tr><td><b>Folderpath:</b></td><td>$($result.xmlnode.ParsedXml._Path)</td></tr>"}
    }
    
    #if (($result.settingName) -and (($result.CategoryPath) -notlike "*Administrative Templates*") -and (($result.CategoryPath) -notlike "*Security Settings*")){$TableOfResults += "<tr><td><b>SettingName:</b></td><td>$($result.SettingName)</td></tr>"}
    #if (($result.CategoryPath) -like "*:FolderAdministrative Templates*") -and (($result.CategoryPath) -notlike "*Security Settings*")){$TableOfResults += "<tr><td><b>SettingName:</b></td><td>$($result.SettingName)</td></tr>"}
        #if ($result.xmlnode.ParsedXml._Path){$TableOfResults += "<tr><td><b>Folderpath:</b></td><td>$($result.xmlnode.ParsedXml._Path)</td></tr>"}

    #endregion -[END Folder settings]--------------------------------------------------------------

    #region ----[Start Registry]-------------------------------------------------------------------
    if ($result.XmlNode.ParentHierarchy -contains "Registry"){
        if ($result.xmlnode.ParsedXml.Properties._hive){$TableOfResults += "<tr><td><b>Hive:</b></td><td>$($result.xmlnode.ParsedXml.Properties._hive)</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._key){$TableOfResults += "<tr><td><b>Key:</b></td><td>$($result.xmlnode.ParsedXml.Properties._key)</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._type){$TableOfResults += "<tr><td><b>Type:</b></td><td>$($result.xmlnode.ParsedXml.Properties._type)</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._value){$TableOfResults += "<tr><td><b>Type:</b></td><td>$($result.xmlnode.ParsedXml.Properties._value)</td></tr>"}
    }
    #endregion -[END Registry]---------------------------------------------------------------------

    #region ----[Start Shortcut settings]----------------------------------------------------------
    if ($result.XmlNode.ParentHierarchy -contains "Shortcut"){
        $TableOfResults += "<tr><td><b>TEST - Type:</b></td><td>$($result.XmlNode.ElementName)</td></tr>"
        if ($result.xmlnode.ParsedXml.Properties._shortcutPath){$TableOfResults += "<tr><td><b>Shortcut Path:</b></td><td>$($result.xmlnode.ParsedXml.Properties._shortcutPath)</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._targetPath){$TableOfResults += "<tr><td><b>Target Path:</b></td><td>$($result.xmlnode.ParsedXml.Properties._targetPath)</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._arguments){$TableOfResults += "<tr><td><b>Argument:</b></td><td>$($result.xmlnode.ParsedXml.Properties._arguments)</td></tr>"}
    }
    #endregion -[END Shortcut settings]------------------------------------------------------------
    
    #region ----[Start Scheduled tasks]------------------------------------------------------------
    if ($result.XmlNode.ParentHierarchy -contains "ScheduledTasks"){
        if ($result.XmlNode.parsedXml.task.triggers.LogonTrigger){$TableOfResults += "<tr><td><b>Trigger:</b></td><td>Logon</td></tr>"}
        if ($result.XmlNode.parsedXml.task.triggers.EventTrigger){$TableOfResults += "<tr><td><b>Trigger:</b></td><td>Event:$($result.XmlNode.parsedXml.task.Triggers.EventTrigger.Subscription)</td></tr>"}
        if ($result.XmlNode.parsedXml.task.triggers.CalendarTrigger){$TableOfResults += "<tr><td><b>Trigger:</b></td><td>Event:$($result.XmlNode.parsedXml.task.Triggers.CalendarTrigger)</td></tr>"}
        if ($result.XmlNode.parsedXml.task.Actions.exec.command){$TableOfResults += "<tr><td><b>Command:</b></td><td>$($result.XmlNode.parsedXml.task.Actions.exec.command)</td></tr>"}
        if ($result.XmlNode.parsedXml.task.Actions.exec.Arguments){$TableOfResults += "<tr><td><b>Argument:</b></td><td>$($result.XmlNode.parsedXml.task.Actions.exec.Arguments)</td></tr>"}
    }
    #if ($result.XmlNode.parsedXml.task.RegistrationInfo.Descriptionlt.xmlnode.ParsedXml._changed){$TableOfResults += "<tr><td><b>Last changed:</b></td><td>$($result.xmlnode.ParsedXml._changed)</td></tr>"}
    #endregion -[END Scheduled tasks]--------------------------------------------------------------
    # test if CategoryPath is ready
    $TableOfResults += "<tr><td><b>TEST - Type:</b></td><td>$($result.XmlNode.ElementName)</td></tr>"

    # informations there only in GPP
    # description
    if ($result.xmlnode.ParsedXml._desc){
        $desc = ($result.xmlnode.ParsedXml._desc) -replace (";","<br>")
        $TableOfResults += "<tr><td><b>Description:</b></td><td>$desc</td></tr>"
    }
    
    if ($result.XmlNode.parsedXml._action){
        if ($result.XmlNode.parsedXml._action -eq "R"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Replace</td></tr>"}
        if ($result.XmlNode.parsedXml._action -eq "U"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Update</td></tr>"}
        if ($result.XmlNode.parsedXml._action -eq "D"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Delete</td></tr>"}        
    }
    if ($result.xmlnode.ParsedXml.Properties._action){
        if ($result.xmlnode.ParsedXml.Properties._action -eq "R"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Replace</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._action -eq "U"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Update</td></tr>"}
        if ($result.xmlnode.ParsedXml.Properties._action -eq "D"){$TableOfResults += "<tr><td><b>Action:</b></td><td>Delete</td></tr>"}
    }
    if ($result.XmlNode.parsedXml.task.RegistrationInfo.Descriptionlt.xmlnode.ParsedXml._changed){$TableOfResults += "<tr><td><b>Last changed:</b></td><td>$($result.xmlnode.ParsedXml._changed)</td></tr>"}
    if ($result.xmlnode.ParsedXml._changed){$TableOfResults += "<tr><td><b>Last changed:</b></td><td>$($result.xmlnode.ParsedXml._changed) </td></tr>"}

    #endregion -[END GPP settings]-----------------------------------------------------------------

    # AA comment 
    if ($result.XmlNode.ParsedXml.Comment){
        $comment = ($result.XmlNode.ParsedXml.Comment) -replace (";","<br>")
        $TableOfResults += "<tr><td><b>Comment:</b></td><td>$Comment</td></tr>"
    }
    # setting description from MS
    if ($result.XmlNode.ParsedXml.Explain){$TableOfResults += "<tr><td><b>Explain:</b></td><td>$($result.XmlNode.ParsedXml.Explain)</td></tr>"}
    
    # end of Table
    $TableOfResults += "</table>"
    $TableOfResults += "<br>"
    #region ----[End create table for the results]-------------------------------------------------
}
    # test only
    "---------------------"
    $result.XmlNode.parsedXml.Member.Name.Text
    "--------------------"
    $result.CategoryPath
    "-------------------"
    $result.Comment
    "-----------------------------------"
    $SearchString
    ($allResults.count)
    "-----------------------------------"

# start generate report
New-Report -PageTitle "Search result for String:" -SearchString $SearchString -TableOne $TableOne -TableOfResults $TableOfResults -ResultCount ($allResults.count)
get-gporeport -Name TestPolicy1 -ReportType xml -Path c:\temp\GPP.xml
