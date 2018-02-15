
[cmdletbinding()]

param(
    [Parameter(Mandatory = $true)]
    [string]
    $ImagePath,

    [Parameter(Mandatory = $true)]
    [string]
    $MSVisionAPIKey,

    [Parameter(Mandatory = $true)]
    [string]
    $MSVisionAPIURI
)



if (!$MSVisionAPIURI.EndsWith('/recognizeText')) {
    $MSVisionAPIURI += '/recognizeText'
}

$requestParameters = "?handwriting=true"

$MSVisionAPIURI += $requestParameters

$headerVisionAPI = @{
    'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
    'Content-Type'              = 'application/octet-stream'
}

$callHWAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $ImagePath

$resultURI = ($callHWAPI).Headers['operation-location']

$finalResult = Invoke-WebRequest -Uri $resultURI -Headers $headerVisionAPI -Method Get

while (($finalResult).Content -Like "*Running*")
{
    $finalResult = Invoke-WebRequest -Uri $resultURI -Headers $headerVisionAPI -Method Get
}

$resultContent = $finalResult.Content | ConvertFrom-Json

$output = $resultContent.recognitionResult.lines.text

Write-Output $output

