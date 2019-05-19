function ConvertTo-Base64{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $True, ParameterSetName = "File")]
        [System.IO.FileInfo[]]$InputFile,

        [Parameter(ValueFromPipeline = $True, ParameterSetName = "Text")]
        [string]$InputText
    )

    Begin {
        $base64StringArray = @{}
    }

    Process {
        try {

            $uniqueID = (New-Guid).Guid

            if ($InputFile) {
                # Convert the Input File Contents into a Base64 format string
                $base64String = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($InputFile.FullName))

                # Add the original File Name (and not path) as KEY and converted Base64 file contents as VALUE to the
                # output Hashtable. Since we support Inclusion of duplicate Key's also in this output Hashtable, we
                # prefix a unique GUID before each KEY separated by an Underscore ('_') like this
                # "xxxx-xxxx-xxxx-xxxx_OriginalFileName" where "xxxx-xxxx-xxxx-xxxx" is the GUID and "OriginalFileName"
                # is the original file being converted
                $base64StringArray.Add(($uniqueID + "_" + $InputFile.Name), $base64String)
            }
            elseif ($InputText){
                # Convert the Input String into a Base64 format string
                $base64String = [System.Convert]::ToBase64String([system.Text.Encoding]::UTF8.GetBytes($InputText))

                # Add the original string as KEY and converted Base64 string as VALUE to the output Hashtable.
                # Since we support Inclusion of duplicate Key's also in this output Hashtable, we prefix a unique
                # GUID before each KEY separated by an Underscore ('_') like this "xxxx-xxxx-xxxx-xxxx_OriginalText"
                # where "xxxx-xxxx-xxxx-xxxx" is the GUID and "OriginalText" is the original text being converted
                $base64StringArray.Add(($uniqueID + "_" + $InputText), $base64String)
            }
        }
        catch [System.IO.FileNotFoundException] {
            Write-Error -Message "Couldn't find the File $InputFile" -ErrorAction Continue
        }
        catch [System.IO.IOException] {
            Write-Error -Message "A File IO Exception happened: $PSItem" -ErrorAction Stop
        }
        catch{
            Write-Error $PSItem -ErrorAction Stop
        }
    }

    End {
        Write-Output $base64StringArray
    }
}