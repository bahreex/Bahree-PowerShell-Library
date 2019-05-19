function Get-OCRTextFromImage {

   	<#
	.SYNOPSIS
		This function gets the printed text from within one or more Images passed, using OCR through MS Computer Vision API.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.jpg' | Get-OCRTextFromImage

		This example finds the C:\Screenshot1.jpg with Get-Item, passes it through the pipeline to Get-OCRTextFromImage which will
		then call the Microsoft Computer Vision API to Identify and return the Printed text within the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.jpg' | Get-OCRTextFromImage

        This example will find all the Images with .JPG extension in the folder C:\Images, passes each of them through
        the pipeline to Get-OCRTextFromImage, which will then call the Microsoft Computer Vision API to Identify and
        return the Printed text within each Image one by one.

	.EXAMPLE
		PS> Get-Content -Path 'C:\ImagesList.txt' | Get-OCRTextFromImage

        This example will read the ImageList.txt file, and assuming that each line in the file represents an Image
        path or URI, it would validate the path/URI and locate that Image. It will then pass each of the Images
        corresponding to each Image path/URI through the pipeline to Get-OCRTextFromImage, which will then call the
        Microsoft Computer Vision API to Identify and return the Printed text within each Image one by one. If any of
        the lines in the file does not represent an Image path/URI (like if it is a directory only path, or a random
        string or an Invalid URI etc.) it is Identified as an error and skipped for the next entry in the file

    .EXAMPLE
		PS> Get-OCRTextFromImage -File "C:\Image1.png" -MSVisionAPIKey "123-456-789-000" -MSVisionAPIURI "https://xxxxx"

        This example will

    .EXAMPLE
		PS> Get-OCRTextFromImage -File (Get-Item -Path 'C:\img.jpg') -MSVisionAPIKey "123-456-789-000" -MSVisionAPIURI "https://xxxxx"

        This example will

    .EXAMPLE
		PS> Get-OCRTextFromImage -File 'http://abc.com/img1.jpg' -MSVisionAPIKey "123-456-789-000" -MSVisionAPIURI "https://xxxxx"

        This example will

	.PARAMETER File
        A System.Object type array representing Image(s). You can pass a string to this parameter (like path to an
        Image on your local drive) or a FIleInfo Object (like you get as a return from Get-ChildItem or Get-Item cmdlets)
        or a URI to an Image. You cannot pass a directory only path (without an Image file name) or any other type.

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for OCR Text Recognition

    #>

    [cmdletbinding()]
    [OutputType('System.String')]
    param(

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]]$File,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI,

        [Parameter()]
        [switch]$Detail

    )

    Begin {

        if (!$MSVisionAPIURI.EndsWith('/ocr')) {
            $MSVisionAPIURI += '/ocr'
        }

        $requestParameters = "?language=unk&detectOrientation=true"

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }
    }

    Process {

        foreach ($FileItem in $File) {
            # Initialize the InputFile variable to null for each iteration for each Input run
            $InputFile = $null

            $resultsObject = [pscustomobject]@{
                ImageRef     = ""
                OCRStatus    = ""
                ImageOCRText = ""
            }

            # Check if the value passed to the param File is a String type
            if ($FileItem -is [System.String]) {

                # Test if the path in File parameter includes an Image file name
                if (Test-Path -Path $FileItem -PathType Leaf) {

                    $InputFile = $FileItem
                }
                # Test if the path in File parameter only includes a directory path but not an Image file name
                elseif (Test-Path -Path $FileItem -PathType Container) {

                    $errMsg = "[Error] Invalid File Input. Directory Path without Filename passed. Only full Image File path OR [System.IO.FileInfo] object OR valid Image URI allowed."
                }
                # Check if the string passed in File parameter is a URI to an Image
                elseif ($FileItem.ToString().StartsWith("http")) {

                    # Make an HTTP Head reaquest to the URI sot hat we can test the URI, but do not download anything
                    $response = Invoke-WebRequest -Uri $FileItem.ToString() -UseBasicParsing -Method Head -DisableKeepAlive

                    if (($response.StatusCode -eq 200) -and ($response.ContentType -eq "application/octet-stream")) {
                        $InputFile = $FileItem.ToString()
                    }
                    else {
                        $errMsg = "[Error] Invalid File Input. Invalid IMage URI passed. Only full Image File path OR [System.IO.FileInfo] object OR valid Image URI allowed."
                    }
                }
                # Handle when the string passed in File parameter is neither a path to an Image file nor a Directory path
                # nor an URI
                else {

                    $errMsg = "[Error] Invalid File Input. Random String Literal passed. Only full Image File path OR [System.IO.FileInfo] object OR valid Image URI allowed."
                }
            }
            # Check if the value of File parameter passed is a FileInfo object
            elseif ($FileItem -is [System.IO.FileInfo]) {

                $InputFile = $FileItem.FullName
            }
            # Handle when the type passed in File parameter is neither a string nor a FileInfo, but any other random type
            else {

                $errMsg = "[Error] Invalid File Input. Passing a random type not allowed. Only String OR [System.IO.FileInfo] object allowed."
            }

            # Check if the Input file to be processed for OCR is not NULL. If there are any Issues with the Input File
            # parameter, the value of Input file will remain NULL, and OCR processing will be skipped for this Instance,
            # moving onto the next Input if being processed from the PowerShell pipeline
            if ($InputFile) {

                try {

                    $invokeWebRequestSplat = @{
                        Method = 'Post'
                        Headers = $headerVisionAPI
                        Uri = $MSVisionAPIURI
                        InFile = $InputFile
                    }
                    $callOCRAPI = Invoke-WebRequest @invokeWebRequestSplat
                    Write-Verbose "Web Response received from calling the OCR REST API: $callOCRAPI"

                    $resultContent = ($callOCRAPI).Content | ConvertFrom-Json
                    Write-Verbose "Content received from calling the OCR REST API: $resultContent"

                    $output = $resultContent.regions.lines.words.text -join " "

                    if ($Detail) {
                        $resultsObject.ImageRef = $InputFile
                        $resultsObject.ImageOCRText = $output
                        $resultsObject.OCRStatus = "Success"
                        Write-Output $resultsObject
                    }
                    else {
                        Write-Output $output
                    }
                }
                catch {
                    Write-Error "Unable to fetch results for Image $InputFile. The Error encountered was: $($_.Exception)."
                }
            }
            else {
                if ($Detail) {
                    $resultsObject.ImageRef = $FileItem
                    $resultsObject.ImageOCRText = ""
                    $resultsObject.OCRStatus = $errMsg
                    Write-Output $resultsObject
                }
                else {
                    Write-Output "$errMsg"
                }
            }
        }
    }
    End {}
}

function Get-HandwritingTextFromImage {

    <#
	.SYNOPSIS
        This function gets the Handwriting text within one or more Images passed, using Handwriting Text Recognition
        through MS Computer Vision API.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.jpg' | Get-HandwritingTextFromImage

        This example finds the C:\Screenshot1.jpg with Get-Item, passes it through the pipeline to
        Get-HandwritingTextFromImage which will then call the Microsoft Computer Vision API to Identify and return the
        Handwritten text within the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.jpg' | Get-HandwritingTextFromImage

        This example will find all the Images with .JPG extension in the folder C:\Images, passes each of them through
        the pipeline to Get-HandwritingTextFromImage, which will then call the Microsoft Computer Vision API to Identify
        and return the Handwritten text within each Image one by one.

	.PARAMETER File
        A System.IO.FileInfo object representing an Image with Handwritten text.

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for Handwriting Text Recognition

    #>
    [cmdletbinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI
    )

    Begin {
        if (!$MSVisionAPIURI.EndsWith('/models/landmarks/analyze')) {
            $MSVisionAPIURI += '/models/landmarks/analyze'
        }

        $requestParameters = "?handwriting=true"

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }

        $resultText = @()
    }

    Process {
        $callHWAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $File.FullName

        $resultURI = ($callHWAPI).Headers['operation-location']

        $finalResult = Invoke-WebRequest -Uri $resultURI -Headers $headerVisionAPI -Method Get

        while (($finalResult).Content -Like "*Running*") {
            $finalResult = Invoke-WebRequest -Uri $resultURI -Headers $headerVisionAPI -Method Get
        }

        $resultContent = $finalResult.Content | ConvertFrom-Json

        $output = $resultContent.recognitionResult.lines.text

        $resultText += $output
    }

    End {
        $resultText
    }
}

function Get-SmartThumbnailFromImage {

    <#
	.SYNOPSIS
		This function generates smart thumbnails for one or more Images passed to it, through MS Computer Vision API.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.png' | Get-SmartThumbnailFromImage

        This example finds the C:\Screenshot1.png with Get-Item, passes it through the pipeline to
        Get-SmartThumbnailFromImage, which will then call the Microsoft Computer Vision API to generate and return a
        thumbnail for the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.png' | Get-SmartThumbnailFromImage

        This example will find all the Images with .PNG extension in the folder C:\Images, passes them through the
        pipeline to Get-SmartThumbnailFromImage, which will then call the Microsoft Computer Vision API to generate and
        return thumbnails for each Image.

	.PARAMETER File
        A System.IO.FileInfo object representing an Image.

    .PARAMETER ThumbnailWidth
        An Integer representing the Thumbnail Width. Default value is 200

    .PARAMETER ThumbnailHeight
        An Integer representing the Thumbnail Height. Default value is 150

    .PARAMETER SmartCropping
        A boolean representing the choice to do SmartCropping or not. Default value is true

    .PARAMETER ThumbnailDir
        A string respresnting the directory where you want the generated thumbnails to be stored. Default is the same
        directory as the location of the original Image

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for generating thumbnails

    #>

    [cmdletbinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$File,

        [Parameter()]
        [int]$ThumbnailWidth = 200,

        [Parameter()]
        [int]$ThumbnailHeight = 150,

        [Parameter()]
        [string]$ThumbnailDir,

        [Parameter()]
        [bool]$SmartCropping = $true,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI
    )
    Begin {
        if (!$MSVisionAPIURI.EndsWith('/generateThumbnail')) {
            $MSVisionAPIURI += '/generateThumbnail'
        }

        $requestParameters = "?" + "width=" + $ThumbnailWidth + "&height=" + $ThumbnailHeight + "&smartCropping=" + $SmartCropping

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }

        $resultThumbnails = @()
    }

    Process {

        $callTNAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $File.FullName

        if ($ThumbnailDir) {
            $thumbnailFullName = $ThumbnailDir + "\" + "thumb_" + $ThumbnailWidth + "x" + $ThumbnailHeight + "_" + $File.BaseName + $File.Extension
        }
        else {
            $thumbnailFullName = $File.Directory + "\" + "thumb_" + $ThumbnailWidth + "x" + $ThumbnailHeight + "_" + $File.BaseName + $File.Extension
        }

        $callTNAPI.Content | Set-Content $thumbnailFullName +  -Encoding Byte

        $resultThumbnails += $thumbnailFullName
    }

    End {
        $resultThumbnails
    }
}

function Get-ImageAnalysisInfo {

    <#
	.SYNOPSIS
		This function analyses one or more Images passed to it, and returns the detailed analysis Information.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.png' | Get-ImageAnalysisInfo

        This example finds the C:\Screenshot1.png with Get-Item, passes it through the pipeline to
        Get-ImageAnalysisInfo, which will then call the Microsoft Computer Vision API to analyze and return
        detailed analysis Information for the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.png' | Get-ImageAnalysisInfo

        This example will find all the Images with .PNG extension in the folder C:\Images, passes them through the
        pipeline to Get-ImageAnalysisInfo, which will then call the Microsoft Computer Vision API to analyze and return
        detailed analysis Information for each Image.

	.PARAMETER File
        A System.IO.FileInfo object representing an Image to be analyzed.

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for analyzing the Image
    #>

    [cmdletbinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI
    )
    Begin {

        if (!$MSVisionAPIURI.EndsWith('/analyze')) {
            $MSVisionAPIURI += '/analyze'
        }

        $requestParameters = "?" + "visualFeatures=Categories,Description,Color&language=en&details"

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }

        $resultAnalysis = @()
    }

    Process {

        $callAnalysisAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $File.FullName

        $result = $callAnalysisAPI.Content | ConvertFrom-Json

        $resultAnalysis += $result
    }

    End {
        $resultAnalysis
    }
}

function Get-LandmarksInImage {

    <#
	.SYNOPSIS
		This function gets names of all the landmarks within one or more Images passed, through MS Computer Vision API.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.jpg' | Get-LandmarksInImage

        This example finds the C:\Screenshot1.jpg with Get-Item, passes it through the pipeline to
        Get-LandmarksInImage, which will then call the Microsoft Computer Vision API to Identify and return names
        of the landmarks within the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.jpg' | Get-LandmarksInImage

        This example will find all the Images with .JPG extension in the folder C:\Images, passes each of them through
        the pipeline to Get-LandmarksInImage, which will then call the Microsoft Computer Vision API to Identify
        and return names of all the landmarks within each Image.

	.PARAMETER File
        A System.IO.FileInfo object representing an Image containing a landmark.

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for recognizing landmarks in an Image

    #>
    [cmdletbinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI
    )

    Begin {

        $MSVisionAPIKey = '7ed4743608de4879ab1c491153ee1fcf'
        $MSVisionAPIURI = 'https://westcentralus.api.cognitive.microsoft.com/vision/v1.0'
        $File = "g:\lm.jpg"

        if (!$MSVisionAPIURI.EndsWith('/models/landmarks/analyze')) {
            $MSVisionAPIURI += '/models/landmarks/analyze'
        }

        $requestParameters = "?" + "model=landmarks"

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }

        $resultHashtable = @{}
    }

    Process {
        $callModelAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $File #.FullName

        $resultContent = $callModelAPI.Content | ConvertFrom-Json

        $resultHashtable.Add($resultContent.result.landmarks.name, $resultContent.result.landmarks.confidence)
    }

    End {
        $resultHashtable
    }
}

function Get-CelebritiesInImage {

    <#
	.SYNOPSIS
        This function gets names of all the recognized Celebrities within one or more Images passed, through
        MS Computer Vision API.

	.EXAMPLE
		PS> Get-Item -Path 'C:\Screenshot1.jpg' | Get-CelebritiesInImage

        This example finds the C:\Screenshot1.jpg with Get-Item, passes it through the pipeline to
        Get-CelebritiesInImage which will then call the Microsoft Computer Vision API to Identify and return names
        of all the Celebrities present within the Image.

	.EXAMPLE
		PS> Get-ChildItem -Path 'C:\Images\*.jpg' | Get-CelebritiesInImage

        This example will find all the Images with .JPG extension in the folder C:\Images, passes each of them through
        the pipeline to Get-CelebritiesInImage, which will then call the Microsoft Computer Vision API to Identify
        and return all the Celebrities present within each Image.

	.PARAMETER File
        A System.IO.FileInfo object representing an Image with one or more Celebrities faces.

    .PARAMETER MSVisionAPIKey
        A string representing the MS Computer Vision API Key for the caller's account

    .PARAMETER MSVisionAPIURI
        A string representing the MS Computer Vision API URI to call for recognizing celebrities in an Image

    #>
    [cmdletbinding()]
    [OutputType('System.String')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$MSVisionAPIURI
    )

    Begin {

        $MSVisionAPIKey = '7ed4743608de4879ab1c491153ee1fcf'
        $MSVisionAPIURI = 'https://westcentralus.api.cognitive.microsoft.com/vision/v1.0'
        $File = "g:\jd.jpg"

        if (!$MSVisionAPIURI.EndsWith('/models/celebrities/analyze')) {
            $MSVisionAPIURI += '/models/celebrities/analyze'
        }

        $requestParameters = "?" + "model=celebrities"

        $MSVisionAPIURI += $requestParameters

        $headerVisionAPI = @{
            'Ocp-Apim-Subscription-Key' = $MSVisionAPIKey
            'Content-Type'              = 'application/octet-stream'
        }

        $resultText = @{}
    }

    Process {
        $callModelAPI = Invoke-WebRequest -Uri $MSVisionAPIURI -Headers $headerVisionAPI -Method Post -InFile $File #.FullName

        $resultContent = $callModelAPI.Content | ConvertFrom-Json

        $resultContent.result.celebrities | ForEach-Object {$resultText.Add($_.name, $_.confidence)}
    }

    End {
        $resultText
    }
}

