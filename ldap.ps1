$DomainParts = $fullDomain.Split(".")
$DN = ($DomainParts | % {"DC=$_"}) -join ","
$LDAPPath = "LDAP://$DN"
$dirSearch = New-Object System.DirectoryServices.DirectorySearcher
$dirSearch.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
$dirSearch.Filter = "(CN=Domain Users)"
$dirSearch.PropertiesToLoad.Add("CN")
$dirSearch.PropertiesToLoad.Add("sAMAccountName")
$dirSearch.PropertiesToLoad.Add("description")
$resultSearch = $dirSearch.FindOne()
$SAN = $resultSearch.Properties.sAMAccountName
$CN = $resultSearch.Properties.CN
if($true){}