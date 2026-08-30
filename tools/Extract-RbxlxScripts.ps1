param(
  [Parameter(Mandatory=$true)][string]$SourcePath,
  [Parameter(Mandatory=$true)][string]$OutDir
)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
[xml]$xml = Get-Content -Raw $SourcePath
function Sanitize([string]$s){ if(-not $s){ return "Unnamed" } return ($s -replace '[\\/:*?"<>|]', '_') }
function GetName($item){
  $nameNode = $item.SelectSingleNode("./Properties/string[@name='Name']")
  if($nameNode){ return $nameNode.InnerText }
  return $item.GetAttribute("class")
}
function GetParentItem($node){
  $p = $node.ParentNode
  while($p -and $p.Name -ne "Item"){ $p = $p.ParentNode }
  return $p
}
function GetPath($node){
  $segments = New-Object System.Collections.Generic.List[string]
  $current = $node
  while($current -and $current.Name -eq "Item"){
    $segments.Add((GetName $current))
    $current = GetParentItem $current
  }
  $arr = $segments.ToArray()
  [array]::Reverse($arr)
  return ($arr -join "/")
}

$scriptNodes = $xml.SelectNodes("//Item[@class='Script' or @class='LocalScript' or @class='ModuleScript']")
$scriptItems = @()
foreach($node in $scriptNodes){
  $class = $node.GetAttribute("class")
  $name = GetName $node
  $pathStr = GetPath $node
  $srcNode = $node.SelectSingleNode("./Properties/ProtectedString[@name='Source']")
  $src = if($srcNode){$srcNode.InnerText} else { "" }
  $safePath = Sanitize($pathStr)
  $fileBase = "$safePath-$class.lua"
  $filePath = Join-Path $OutDir $fileBase
  $i=1
  while(Test-Path $filePath){
    $filePath = Join-Path $OutDir ("$safePath-$class-$i.lua")
    $i++
  }
  Set-Content -Path $filePath -Value $src -Encoding UTF8
  $scriptItems += [pscustomobject]@{path=$pathStr; class=$class; name=$name; file=$filePath; referent=$node.GetAttribute("referent")}
}
$manifest = Join-Path $OutDir "manifest.json"
$scriptItems | ConvertTo-Json -Depth 4 | Set-Content -Path $manifest -Encoding UTF8
$scriptItems.Count
