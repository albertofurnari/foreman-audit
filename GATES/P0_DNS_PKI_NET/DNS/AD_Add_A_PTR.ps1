Param(
  [Parameter(Mandatory=$true)][string]$CsvPath = ".\dns_records.csv",
  [string]$Ttl = "01:00:00",  # TTL 1h
  [string]$ReplicationScope = "Domain"
)

Import-Module DnsServer -ErrorAction Stop
$recs = Import-Csv -Path $CsvPath

function Ensure-ForwardZone($Zone) {
  $z = Get-DnsServerZone -Name $Zone -ErrorAction SilentlyContinue
  if (-not $z) {
    Write-Host "Creating forward zone $Zone"
    Add-DnsServerPrimaryZone -Name $Zone -DynamicUpdate Secure -ReplicationScope $ReplicationScope | Out-Null
  }
}

function Ensure-ReverseZone($RevZone) {
  $z = Get-DnsServerZone -Name $RevZone -ErrorAction SilentlyContinue
  if (-not $z) {
    # Prova con NetworkId se è /24
    $parts = $RevZone -split '\.'
    if ($parts.Count -ge 4 -and $parts[-2] -eq 'arpa') {
      # es: 8.168.192.in-addr.arpa -> 192.168.8.0/24
      $oct = @($parts[2], $parts[1], $parts[0])
      $net = "$($oct[0]).$($oct[1]).$($oct[2]).0/24"
      Write-Host "Creating reverse zone $RevZone (net $net)"
      Add-DnsServerPrimaryZone -NetworkId $net -ReplicationScope $ReplicationScope | Out-Null
    } else {
      Write-Warning "Reverse zone $RevZone non riconosciuta automaticamente; creare manualmente."
    }
  }
}

function Ensure-ARecord($Zone, $Fqdn, $Ip, $Ttl) {
  $label = $Fqdn -replace ("\." + [regex]::Escape($Zone) + "$"), ""
  if ($label -match "\.$") { $label = $label.TrimEnd('.') }
  $label = $label.Split('.')[0]
  $curr = Get-DnsServerResourceRecord -ZoneName $Zone -Name $label -RRType A -ErrorAction SilentlyContinue
  if (-not $curr) {
    Add-DnsServerResourceRecordA -ZoneName $Zone -Name $label -IPv4Address $Ip -TimeToLive $Ttl | Out-Null
    Write-Host "A  $Fqdn -> $Ip   [CREATED]"
  } elseif ($curr.RecordData.IPv4Address.IPAddressToString -ne $Ip) {
    Set-DnsServerResourceRecord -NewInputObject (New-DnsServerResourceRecord -A -Name $label -IPv4Address $Ip -TimeToLive $Ttl) `
      -OldInputObject $curr -ZoneName $Zone -PassThru | Out-Null
    Write-Host "A  $Fqdn -> $Ip   [UPDATED]"
  } else {
    Write-Host "A  $Fqdn -> $Ip   [OK]"
  }
}

function Ensure-PTRRecord($RevZone, $Fqdn, $Ip, $Ttl) {
  $lastOctet = ($Ip.Split('.'))[-1]
  $ptr = Get-DnsServerResourceRecord -ZoneName $RevZone -Name $lastOctet -RRType PTR -ErrorAction SilentlyContinue
  $target = ($Fqdn.TrimEnd('.') + '.')
  if (-not $ptr) {
    Add-DnsServerResourceRecordPtr -ZoneName $RevZone -Name $lastOctet -PtrDomainName $target -TimeToLive $Ttl | Out-Null
    Write-Host "PTR $Ip -> $target [CREATED]"
  } elseif ($ptr.RecordData.PtrDomainName -ne $target) {
    Set-DnsServerResourceRecord -NewInputObject (New-DnsServerResourceRecord -Ptr -Name $lastOctet -PtrDomainName $target -TimeToLive $Ttl) `
      -OldInputObject $ptr -ZoneName $RevZone -PassThru | Out-Null
    Write-Host "PTR $Ip -> $target [UPDATED]"
  } else {
    Write-Host "PTR $Ip -> $target [OK]"
  }
}

foreach ($r in $recs) {
  Ensure-ForwardZone $r.forward_zone
  Ensure-ReverseZone $r.reverse_zone
  Ensure-ARecord      $r.forward_zone $r.fqdn $r.ip $Ttl
  Ensure-PTRRecord    $r.reverse_zone $r.fqdn $r.ip $Ttl
}

