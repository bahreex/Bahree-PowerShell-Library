
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

$MSVisionAPIKey = '7ed4743608de4879ab1c491153ee1fcf'
$MSVisionAPIURI = 'https://westcentralus.api.cognitive.microsoft.com/vision/v1.0'

if (!$MSVisionAPIURI.EndsWith('/ocr')) {
    $MSVisionAPIURI += '/ocr'
}

$requestParameters = "?language=unk&detectOrientation=true"

$MSVisionAPIURI += $requestParameters

$headerVisionAPI = @{
    'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
    'Content-Type'              = 'application/octet-stream'
}

$callOCRAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $ImagePath

$resultContent = ($callOCRAPI).Content | ConvertFrom-Json

$output = $resultContent.regions.lines.words.text -join " "

Write-Output $output

