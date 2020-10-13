


Function Deploy-DellBiosDriver {

     

    [CmdletBinding(DefaultParametersetName='None')]
    param(


        [Parameter(Mandatory=$False, ParameterSetName='Override')]
        [Switch]$OverrideAndInstall,

        [Parameter(Mandatory=$False, ParameterSetName='SupressandReboot')]
        [Switch]$SupressUI,
        
        [Parameter(Mandatory=$True, ParameterSetName='SupressandReboot')]
        [Switch]$AutoReboot,        

        [Parameter(Mandatory=$False, ParameterSetName='SupressandReboot')]
        [Switch]$ForceInstallSame,

        [Parameter(Mandatory=$False)]
        $FolderPath,

        [Parameter(Mandatory=$False)]
        $BiosPassword,

        [Parameter(Mandatory=$False)]
        $LogFile,
        
        [Parameter(Mandatory=$False, ParameterSetName='Syntax')]
        [Switch]$Syntax,


        [Parameter(DontShow)]
        $DebugPreference



    )


    
    
    $Host.PrivateData.ProgressBackgroundColor='Black' 
    $Host.PrivateData.ProgressForegroundColor='Cyan'






# Functions for all requests


Function Urls {

    $global:Region = "&country=us&language=en&region=us"
    $global:SeriesURL = "https://www.dell.com/support/components/productselector/allproducts?category=all-products/"
    $global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $global:headers.Add('Accept','*/*')
    
}

# Urls


Function Request {

   

    $global:modelResponse = Invoke-RestMethod $global:ModelsURL -Method GET -Headers $global:headers -ErrorAction 'SilentlyContinue'

    
}



Function Category {
    $global:SeriesRegionURL = $global:SeriesURL + $global:ModelCategory + $global:Region 
}


Function SeriesResponse{
    $global:seriesResponse = Invoke-RestMethod $global:SeriesRegionURL -Method GET -Headers $global:headers -ErrorAction 'SilentlyContinue'
}


Function ModelUrl{
    $global:ModelsURL = $global:SeriesURL + $global:ModelCategory +'/' + "$_" + $global:Region
}


Function CaptureArray{
    $global:ValueAfter = ($global:valueBefore) -replace ('-', ' ')
    $global:ModelArray += $global:ValueAfter
    
}



Function GetDriver{
        $global:matchedModel = $global:ModelArray | ?{$_ -match (Get-CimInstance -Classname "Win32_ComputerSystem").Model}
        $global:ModelHyphen = ($global:matchedModel).replace(" ","-")
        $global:ModelUpper = $global:ModelHyphen.ToUpper()
        $global:DellDriverURL = 'https://www.dell.com/support/driver/en-us/ips/api/driverlist/getdriversbyproduct?productcode='+ $global:ModelHyphen #+'&oscode=WT64A'
        $global:DriverFile = ((Invoke-RestMethod $global:DellDriverURL -Method Get -Headers $global:headers -ErrorAction 'SilentlyContinue').DriverListData | ?{$_.CatName -match "BIOS"}) | Sort-Object ReleaseDateValue -Descending | Select-Object -First 1 | Select DriverName, DellVer, @{Name='DriverFile'; Expression = {$_.FileFrmtInfo.HttpFileLocation}}, @{Name='FileName'; Expression = {$_.FileFrmtInfo.FileName}}
        

}


Function DownloadPath {

    if($null -ne $FolderPath){

        if(!(Test-path $FolderPath)){
            New-Item $FolderPath -ItemType Directory | Out-Null
        }
      $global:DownPath = "$($FolderPath)\$($global:ModelUpper)-BIOS-$($global:driverver).exe"  

    }
    else 
    {
     
      $global:DownPath = "$Env:Temp\$($global:ModelUpper)-BIOS-$($global:driverver).exe"

    }

}




Function Download {


    $uri = New-Object "System.Uri" "$($global:DriverFile.DriverFile)"

    $request = [System.Net.HttpWebRequest]::Create($uri)
 
    $request.set_Timeout(15000) #15 second timeout
 
    $response = $request.GetResponse()
 
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
 
    $responseStream = $response.GetResponseStream()
 
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $($global:DownPath), Create
 
    $buffer = new-object byte[] 10KB
 
    $count = $responseStream.Read($buffer,0,$buffer.length)
 
    $downloadedBytes = $count




    while ($count -gt 0)
                         
                                    {
                                 
                                        $targetStream.Write($buffer, 0, $count)
                                 
                                        $count = $responseStream.Read($buffer,0,$buffer.length)
                                 
                                        $downloadedBytes = $downloadedBytes + $count
                                 
                                        Write-Progress -Id 1 -activity "   Downloading file $newFile" -status "   Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
                                 
                                    }


$targetStream.Flush()

$targetStream.Close()

$targetStream.Dispose()

$responseStream.Dispose()

Write-Progress -Id 1 -Activity " " -Completed









}













Function SupressUI{
    if($SupressUI)
        {
            $global:s = '/s'
            
        }
        else
        {
            $global:s = $null
            
        }

}

Function AutoReboot{
    if($AutoReboot)
        {
            $global:ar = '/r'
            
        }
        else{
            $global:ar = $null
            
        }
    

}


Function BiosPassword{

        if($null -ne $BiosPassword){
            $global:bp = "/p=$($BiosPassword)" 
        
        }
        else{
            $global:bp = $null
        }
        
}






Function LogFile{  
        if($null -ne $LogFile){
            $global:lf = "/l=$($LogFile)"
            
        }
        else{
            $global:lf = $null
        }
}






Function ErrorCorrection{
    $global:BiosCheckProc = (Start-Process "$global:DownPath" -argumentlist "/s","$global:bp","/l=$ENV:Temp\BiosLog-ErrorChecking.txt" -PassThru).ID
    $global:BiosProcStart = 0

            While(!(Get-Process -ID $global:BiosCheckProc).HasExited -and $global:BiosProcStart -lt 15){
                
                If((Get-Process -ID $global:BiosCheckProc).HasExited){
                    break;
                }
                
                Start-Sleep -Seconds 1
                $global:BiosProcStart++
                
            }
            
                    While(!(Get-Process -ID $global:BiosCheckProc).HasExited){
            
                    (Get-Process -ID $global:BiosCheckProc).CloseMainWindow() | Out-Null
            
                    }


}





Function DriverVersion{

    $global:driverver = (($global:DriverFile.DellVer) -split(',')).Trim() | Select -First 1

}







Function InstallProcess {

    $global:Answer = $null


    Switch($OverrideAndInstall){




        'True'{
            
            Download
            BiosPassword
            LogFile
            
            

            ErrorCorrection



                    $error1 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Unsupported System ID Found.').Matches.Value
                    $error2 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Invalid Password').Matches.Value
                    $error3 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Unable to prepare the BIOS update payload').Matches.Value
                    $error4 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: New BIOS is the same as the current BIOS.').Matches.Value
            
                    

            if($null -ne $error1){
            
                
                    return "$error1"
                    exit
                }
            elseif($null -ne $error2){
                
            
                return "$error2"
                exit
            
            }
            elseif($null -ne $error3){
                
            
                return "$error3"
                exit
            
            }
            else{
                    Remove-Item "$ENV:Temp\BiosLog-ErrorChecking.txt" -force
                    Start-Process $global:DownPath -argumentlist "/s","/r","$global:bp","$global:lf","/f"
                
                }
                
                

            

        } #<-- End of 'True' ForceInstallWhenFound Switch Statement





        'False'{


            




Switch($global:DriverFile.DellVer -match (Get-CimInstance -Classname "Win32_BIOS").SMBIOSBIOSVersion){


                            'True'{





Switch($ForceInstallSame){   #<-- Start of 'ForceInstallSame' Switch



'True'{

    $global:Answer = 'y'

}   #<-- End of 'True' ForceInstallSame Switch

'False'{


While("y","n" -notcontains $global:Answer){

Clear

"$($global:DriverFile.DriverName)
$($global:driverver)"

$global:Answer = Read-Host "matches Bios version of driver installed.
Do you still want to download and install it, anyways? (y/n)"
}      #<-- End of Answer 'While' Statement  
        


    } #<-- End of 'False' ForceInstallSame Switch

}   #<-- End of 'ForceInstallSame' Switch




Switch($global:Answer){


'y'{

    
    Download
    SupressUI
    AutoReboot
    BiosPassword
    LogFile
    
    
    
            
    ErrorCorrection



                    
                    
                    $error1 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Invalid Password').Matches.Value 
                    $error2 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Unsupported System ID Found.').Matches.Value
                    
            
            if($null -ne $error2){
            
                
                    return "$error2"
                    exit
                }
            elseif($null -ne $error1){
                
            
                return "$error1"
                exit
            
            }
            else{
                Remove-Item "$ENV:Temp\BiosLog-ErrorChecking.txt" -force
                Start-Process "$global:DownPath" -argumentlist "$global:s","$global:ar","$global:bp","$global:lf","/f"
            }

} #<-- End of 'y' in Switch Statement





'n'{

Exit






} #<-- End of 'n' in Switch Statement







}   #<-- End of 'Answer' Switch Statement






                }  #<-- End of 'True' SMBIOSBIOSVersion Switch Statement
        


                            'False'{









While("y","n" -notcontains $Answer){

Clear

"Found:

$($global:DriverFile.DriverName)
$($global:driverver)
"
$Answer = Read-Host "for your system and seems to be newer than the installed version.

Would you like to download and install it? (y/n)"
}   #<-- End of Answer 'While' Statement        
        





Switch($Answer){


'y'{
            Download
            SupressUI
            AutoReboot
            BiosPassword
            LogFile
            
            
            
            ErrorCorrection


                    
                    
                    $error1 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Invalid Password').Matches.Value 
                    $error2 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'Error: Unsupported System ID Found.').Matches.Value
                    $error3 = (Get-Content "$ENV:Temp\BiosLog-ErrorChecking.txt" | Select-String -pattern 'New BIOS is the same as the current BIOS').Matches.Value
            
            if($null -ne $error2){
            
                
                    return "$error2"
                    exit
                }
            elseif($null -ne $error1){
                
            
                return "$error1"
                exit
            
            }
            elseif($null -ne $error3){
                
            
                return "$error3"
                exit
            
            }
            else{
            Remove-Item "$ENV:Temp\BiosLog-ErrorChecking.txt" -force
            Start-Process "$global:DownPath" -argumentlist "$global:s","$global:ar","$global:bp","$global:lf"
            }
}
'n'{

    
    exit

}



}

        
                } #<-- End of 'False' SMBIOSBIOSVersion Switch Statement
        
        


        
        
            } # End of SMBIOSVersion Switch





        } #<-- End of 'False' ForceInstallWhenFound Switch Statement






    } # End of ForceInstallWhenFound' Switch statement





} #End of 'InstallProcess' Function
















If($Syntax){
    '
    


    Deploy-DellBiosDriver [-FolderPath <Object>] [-BiosPassword <Object>] [-LogFile <Object>]
    
    Deploy-DellBiosDriver [-OverrideAndInstall] [-FolderPath <Object>] [-BiosPassword <Object>] [-LogFile <Object>]
    
    Deploy-DellBiosDriver [-SupressUI] [-AutoReboot] [-ForceInstallSame] [-FolderPath <Object>] [-BiosPassword <Object>] [-LogFile <Object>]
    

    Example:    Deploy-DellBiosDriver -OverrideAndInstall -FolderPath "C:\SomePath" -BiosPassword "abc123" -LogFile "C:\SomePath\SomeLogFile.txt"


    Notes**


    -- If [-SupressUI] is selected, [-AutoReboot] is Mandatory due to .exe operation that powershell has no control over

    -- [-BiosPassword <Object>] & [-LogFile <Object>] are written in plain text strings within single quotes like such'+"  '"+'SomeStringhere'+"'  "+'

    -- [-OverrideAndInstall] is used for overriding all options and finding the BIOS that matches the current system, 
        checking for errors as well as possible, then forcing the install and reboot

    -- If using on the current system, you may opt to force the install, or choose optional parameters or default without parameters 
       by just running Deploy-DellBiosDriver by itself which will grab the bios for the current system and run the GUI for manual mode



    
    '
    break
}






















# Switch($LocalRemote){           #<-- Start of 'LocalRemote' Switch



# 'True'{






    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "Optiplex"){     #<-- If statement for 'system is an OptiPlex'
    $global:ModelArray = @()

    Urls

    $global:ModelCategory = "esuprt_desktop/esuprt_desktop_optiplex"


    Category

    
    SeriesResponse
    
    
    ($global:seriesResponse | Select-String -Pattern 'esuprt_desktop_optiplex_.*?000' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
    
    
    ModelUrl
    
    
    Request

    
    $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('optiplex-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
    CaptureArray
    
    }
      
    


          
    GetDriver
    DriverVersion
    DownloadPath





    InstallProcess
    
    
    



    } # End of 'If' Statement for Optiplex















    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "Latitude"){     #<-- If statement for 'system is a Latitude'
    $global:ModelArray = @()

    Urls




    $global:ModelCategory = "esuprt_laptop/esuprt_laptop_latitude"


    Category

    
    SeriesResponse
    
    
    ($global:seriesResponse | Select-String -Pattern 'esuprt_laptop_latitude_.*?000' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
    
    
    ModelUrl
    
    
    Request

    
    $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('latitude-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
    CaptureArray
    
    }
      
    


          
    GetDriver
    DownloadPath




    InstallProcess


    
    



    } # End of 'If' Statement for Latitude
















    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "XPS"){     #<-- If statement for 'system is an XPS'
    $global:ModelArray = @()

    Urls




    $global:ModelCategory = "esuprt_laptop/esuprt_laptop_xps"


    Category

    
    SeriesResponse
    
    
    ($global:seriesResponse | Select-String -Pattern 'esuprt_laptop_xps_\d.*?\d' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
    
    
    ModelUrl
    
    
    Request

    
    $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('xps-.*?laptop')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
    
    CaptureArray
    
    }
      
    


         
    GetDriver
    DownloadPath



    InstallProcess


    
    



                    } # End of 'If' Statement for XPS



                # }

                # 'False'{

                #     break
                # }




        # }   # End of 'LocalRemote' Switch Statement





} # End of Function 'Install-DellBiosDriver'


 































Function Find-DellBiosDriver{



    [CmdletBinding(DefaultParameterSetName='Set0')]
    param(

        
        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(ParameterSetName='Set2')]
        [Parameter(ParameterSetName='Set3')]
        [Parameter(ParameterSetName='Set4')]
        [Parameter(ParameterSetName='GUI')]
        [Switch]$GUI,

        [Parameter(Mandatory=$False, ParameterSetName='Set1')]
        [Switch]$MatchComputer,

        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(Mandatory=$False, ParameterSetName='Set2')]
        [Parameter(ParameterSetName='GUI')]
        [Parameter(ParameterSetName='List')]
        [Switch]$Optiplex,

        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(Mandatory=$False, ParameterSetName='Set3')]
        [Parameter(ParameterSetName='GUI')]
        [Parameter(ParameterSetName='List')]
        [Switch]$Latitude,

        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(Mandatory=$False, ParameterSetName='Set4')]
        [Parameter(ParameterSetName='GUI')]
        [Parameter(ParameterSetName='List')]
        [Switch]$XPS,

        [Parameter(Mandatory=$False, ParameterSetName='List')]
        [Switch]$ListOnly,

        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(ParameterSetName='Set1')]
        [Parameter(ParameterSetName='Set2')]
        [Parameter(ParameterSetName='Set3')]
        [Parameter(ParameterSetName='Set4')]
        [Parameter(ParameterSetName='GUI')]
        $FolderPath,

        [Parameter(Mandatory=$False, ParameterSetName='Set0')]
        [Parameter(ParameterSetName='Set1')]
        [Parameter(ParameterSetName='Set2')]
        [Parameter(ParameterSetName='Set3')]
        [Parameter(ParameterSetName='Set4')]
        [Parameter(ParameterSetName='List')]
        [Parameter(ParameterSetName='GUI')]
        [Switch]$IncludeLegacy,

        [Parameter(Mandatory=$False, ParameterSetName='Syntax')]
        [Switch]$Syntax,

        [Parameter(DontShow)]
        $DebugPreference




    )

    

    $Host.PrivateData.ProgressBackgroundColor='Black' 
    $Host.PrivateData.ProgressForegroundColor='Cyan'




# Functions for all requests


Function Urls {

    $global:Region = "&country=us&language=en&region=us"
    $global:SeriesURL = "https://www.dell.com/support/components/productselector/allproducts?category=all-products/"
    $global:headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $global:headers.Add('Accept','*/*')
    
}

# Urls


Function Request {

   

    $global:modelResponse = Invoke-RestMethod $global:ModelsURL -Method GET -Headers $global:headers -ErrorAction 'SilentlyContinue'

    
}



Function Category {
    $global:SeriesRegionURL = $global:SeriesURL + $global:ModelCategory + $global:Region 
}


Function SeriesResponse{
    $global:seriesResponse = Invoke-RestMethod $global:SeriesRegionURL -Method GET -Headers $global:headers -ErrorAction 'SilentlyContinue'
}


Function ModelUrl{
    $global:ModelsURL = $global:SeriesURL + $global:ModelCategory +'/' + "$_" + $global:Region
}


Function CaptureArray{
    $global:ValueAfter = ($global:valueBefore) -replace ('-', ' ')
    $global:ModelArray += $global:ValueAfter
    
}



Function GetDriver{
        
        $global:ModelHyphen = ($_) -replace (' ','-')
        $global:ModelUpper = $global:ModelHyphen.ToUpper()
        $global:DellDriverURL = 'https://www.dell.com/support/driver/en-us/ips/api/driverlist/getdriversbyproduct?productcode='+ $global:ModelHyphen #+'&oscode=WT64A'
        $global:DriverFile = ((Invoke-RestMethod $global:DellDriverURL -Method Get -Headers $global:headers -ErrorAction 'SilentlyContinue').DriverListData | ?{$_.CatName -match "BIOS"}) | Sort-Object ReleaseDateValue -Descending | Select-Object -First 1 | Select DriverName, DellVer, @{Name='DriverFile'; Expression = {$_.FileFrmtInfo.HttpFileLocation}}, @{Name='FileName'; Expression = {$_.FileFrmtInfo.FileName}}
        

}


Function GetDriverMatched{
    
    $global:matchedModel = $global:ModelArray | ?{$_ -match (Get-CimInstance -Classname "Win32_ComputerSystem").Model}
    $global:ModelHyphen = ($global:matchedModel) -replace (' ','-')
    $global:ModelUpper = $global:ModelHyphen.ToUpper()
    $global:DellDriverURL = 'https://www.dell.com/support/driver/en-us/ips/api/driverlist/getdriversbyproduct?productcode='+ $global:ModelHyphen #+'&oscode=WT64A'
    $global:DriverFile = ((Invoke-RestMethod $global:DellDriverURL -Method Get -Headers $global:headers -ErrorAction 'SilentlyContinue').DriverListData | ?{$_.CatName -match "BIOS"}) | Sort-Object ReleaseDateValue -Descending | Select-Object -First 1 | Select DriverName, DellVer, @{Name='DriverFile'; Expression = {$_.FileFrmtInfo.HttpFileLocation}}, @{Name='FileName'; Expression = {$_.FileFrmtInfo.FileName}}
      

}




Function DownloadPath {

    $DefaultPath = 'C:\Dell-BIOS-Downloads'


    if($null -ne $FolderPath){

        if(!(Test-path $FolderPath)){
            New-Item $FolderPath -ItemType Directory | Out-Null
        }
      $global:DownPath = "$($FolderPath)\$($global:ModelUpper)-BIOS-$($global:driverver).exe"  
      $global:Path = $FolderPath
    }
    else 
    {
        if(!(Test-path $DefaultPath)){
            New-Item $DefaultPath -ItemType Directory | Out-Null
        }
      $global:DownPath = "$DefaultPath\$($global:ModelUpper)-BIOS-$($global:driverver).exe"

      $global:Path = $DefaultPath
    }

}






Function DriverVersion{

    $global:driverver = (($global:DriverFile.DellVer) -split(',')).Trim() | Select -First 1

}






Function Download {
    

    $uri = New-Object "System.Uri" "$($global:DriverFile.DriverFile)"

    $request = [System.Net.HttpWebRequest]::Create($uri)
 
    $request.set_Timeout(15000) #15 second timeout
 
    $response = $request.GetResponse()
 
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
 
    $responseStream = $response.GetResponseStream()
 
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $($global:DownPath), Create
 
    $buffer = new-object byte[] 10KB
 
    $count = $responseStream.Read($buffer,0,$buffer.length)
 
    $downloadedBytes = $count




    while ($count -gt 0)
                         
{

    $targetStream.Write($buffer, 0, $count)

    $count = $responseStream.Read($buffer,0,$buffer.length)

    $downloadedBytes = $downloadedBytes + $count

    Write-Progress -Id 1 -activity " "  -Status "   Downloading ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): "  -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)

}

$targetStream.Flush()

$targetStream.Close()

$targetStream.Dispose()

$responseStream.Dispose()

Write-Progress -Id 1 -Activity " " -Completed



}










Function Optiplex{

    
    Write-Progress -Id 0 -Activity "Processing Optiplex Models..." -Status " "
    Urls
    $global:ModelCategory = "esuprt_desktop/esuprt_desktop_optiplex"
    Category
    SeriesResponse
    ($global:seriesResponse | Select-String -Pattern 'esuprt_desktop_optiplex_.*?000' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
    ModelUrl
    Request
    $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('optiplex-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
    CaptureArray
    }
    
    If($IncludeLegacy){
        Urls

    $global:ModelCategory = "esuprt_desktop/esuprt_desktop_optiplex/esuprt_desktop_optiplex_legacy"


    Category

    
    SeriesResponse

    (($global:seriesResponse | Select-String -Pattern "('optiplex-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","") | %{
    $global:valueBefore = $_
    CaptureArray



    }
    }

    
    } #<-- End of 'Optiplex Function'





    Function Latitude{

        Write-Progress -Id 0 -Activity "Processing Latitude Models..." -Status " "
       
        Urls
        $global:ModelCategory = "esuprt_laptop/esuprt_laptop_latitude"
        Category
        SeriesResponse
        ($global:seriesResponse | Select-String -Pattern 'esuprt_laptop_latitude_.*?000' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
        ModelUrl
        Request
        $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('latitude-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
        CaptureArray
        }
        
        

        If($IncludeLegacy){
        Urls

        $global:ModelCategory = "esuprt_laptop/esuprt_laptop_latitude/esuprt_laptop_latitude_legacy"


        Category

        
        SeriesResponse

        (($global:seriesResponse | Select-String -Pattern "('latitude-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","") | %{
        
        If ($_ -notmatch 'cport|cdock'){
            $global:valueBefore = $_
            CaptureArray
        }
        



        }
        }

        
        }#<-- End of 'Latitude' Function




        Function XPS{
            
            Write-Progress -Id 0 -Activity "Processing XPS Models..." -Status " "
            Urls
            $global:ModelCategory = "esuprt_laptop/esuprt_laptop_xps"
            Category
            SeriesResponse
            ($global:seriesResponse | Select-String -Pattern 'esuprt_laptop_xps_\d.*?\d' -AllMatches).Matches.Value | %{    #<-- Search Dell for all optiplex series lines
            ModelUrl
            Request
            $global:valueBefore = (($global:modelResponse | Select-String -Pattern "('xps-.*?laptop')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","")
            CaptureArray
            }
        
            If($IncludeLegacy){
                Urls

            $global:ModelCategory = "esuprt_laptop/esuprt_laptop_xps/esuprt_laptop_xps_legacy"


            Category

            
            SeriesResponse

            (($global:seriesResponse | Select-String -Pattern "('xps-.*?')" -AllMatches).Matches.Value | Select-Object -Unique) -replace ("'","") | %{
            
            
                $global:valueBefore = $_
                CaptureArray
            
    



            }
            }
        
            
            }#<-- End of 'XPS' Function
        
        

Function All{
     
     Optiplex

     
     Latitude

     
     XPS
}








If($Syntax){
    '


    
    Find-DellBiosDriver [-GUI] [-Optiplex] [-Latitude] [-XPS] [-FolderPath <Object>] [-IncludeLegacy]

    Find-DellBiosDriver [-MatchComputer] [-FolderPath <Object>] [-IncludeLegacy]
    
    Find-DellBiosDriver [-GUI] [-XPS] [-FolderPath <Object>] [-IncludeLegacy]
    
    Find-DellBiosDriver [-GUI] [-Latitude] [-FolderPath <Object>] [-IncludeLegacy]

    Find-DellBiosDriver [-GUI] [-Optiplex] [-FolderPath <Object>] [-IncludeLegacy]

    Find-DellBiosDriver [-MatchComputer] [-FolderPath <Object>] [-IncludeLegacy]

    Find-DellBiosDriver [-Optiplex] [-Latitude] [-XPS] [-ListOnly] [-IncludeLegacy]

    Find-DellBiosDriver [-Syntax]

    


    Example:    Find-DellBiosDriver -GUI -FolderPath "C:\DellBIOS" -IncludeLegacy


    Notes**



    -- [-GUI] is Optional to display GUI interface for selected options

    -- Currently supported Model Series (Optiplex, Latitude, XPS)

    -- If Model is not on list, add [-IncludeLegacy] as parameter to see if it may be a legacy model

    -- [-FolderPath <Object>] is written in plain text strings within single quotes like such'+"  '"+'C:\SomeFolderPath'+"'  "+'

    -- If [-GUI] is not specified, you may choose the numbers in the list like such '+"'"+'1,2,3'+"'"+' or '+"'"+'1 2 3'+"'"+' or '+"'"+'1..25'+"'"+'


    
    '
    break;
}






            $global:ModelArray = $Null
            $global:ModelArray = @()
        
            
        


            If($ListOnly){


            If($Optiplex){
                Optiplex
                Write-Progress -Id 0 -Activity "Processing" -Completed
                
            }
            If($Latitude){
                Latitude
                Write-Progress -Id 0 -Activity "Processing" -Completed
                
            }
            If($XPS){
                XPS
                Write-Progress -Id 0 -Activity "Processing" -Completed
                
            }
            If(!$Optiplex -and !$Latitude -and !$XPS){
                All
                Write-Progress -Id 0 -Activity "Processing" -Completed
                
            }
            $NumberArray = @()

            $global:ModelArray | %{

                $number = "$($global:ModelArray.IndexOf($_))   -   $($_)"
                $NumberArray += $number

            }
            return $NumberArray
                break;
            

        }













            
        
        
              Switch($MatchComputer){
        
                'True'{
                    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "Optiplex"){

                        Optiplex

                    }
                    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "Latitude"){
                        
                        Latitude
                    }
                    If ((Get-CimInstance -Classname "Win32_ComputerSystem").model -match "XPS"){
                        
                        XPS
                    }
                        GetDriverMatched
                        DriverVersion
                        DownloadPath
                        Write-Progress -Id 0 -Activity "   Downloading     >     $(($global:matchedModel).ToUpper()) BIOS" -Status " "
                        Download
                        Write-Progress -Id 0 -Activity "   Downloading     >     $(($global:matchedModel).ToUpper()) BIOS" -Completed

                        return "

                        Driver has been downloaded to:
                        $($global:Path)
                        
                        "
        
                    
        
        
                }
                'False'{


                   
                    If($Optiplex){
                        Optiplex
                        Write-Progress -Id 0 -Activity "Processing" -Completed
                    }
                    If($Latitude){
                        Latitude
                        Write-Progress -Id 0 -Activity "Processing" -Completed
                    }
                    If($XPS){
                        XPS
                        Write-Progress -Id 0 -Activity "Processing" -Completed
                    }
                    If(!$Optiplex -and !$Latitude -and !$XPS){
                        All
                        Write-Progress -Id 0 -Activity "Processing" -Completed
                    }





                    Switch($GUI){

                        'True'{

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form



$label = New-Object System.Windows.Forms.Label
$label.Top = 10
$label.Left = 85
$label.Size = New-Object System.Drawing.Size(150,20)
$label.Text = 'Please select a model:'
$form.Controls.Add($label)



$okButton = New-Object System.Windows.Forms.Button
$okButton.Top = $($label.Bottom + 20)
$okButton.Left = 65
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $okButton
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Top = $($label.Bottom + 20)
$cancelButton.Left = $($okButton.Right + 20)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::CANCEL
$form.CancelButton = $cancelButton
$form.Controls.Add($cancelButton)



$listBox = New-Object System.Windows.Forms.ListBox
$listbox.ItemHeight = 20
$listBox.SelectionMode = 'MultiExtended'
$listBox.Top = $($okButton.Bottom + 20)
$listBox.Left = 3
$listBox.Width = 300
$listBox.Height = 500



$global:ModelArray | %{

    [void] $listBox.Items.Add("$_")

}

$form.Controls.Add($listBox)
$form.AutoSize = 'True'
$form.Text = 'Select a Computer'
$form.StartPosition = 'CenterScreen'

$form.Topmost = $true


$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $global:X = $null
    $global:X = $listBox.SelectedItems




    
    $global:X | %{
        Write-Progress -Id 0 -Activity "   Downloading  $($global:X.Indexof($_)+1) of $($global:X.Count)     >      $(($_).ToUpper()) BIOS" -Status " "

        GetDriver
        DriverVersion
        DownloadPath
        
        Try{
                
        Download
        
        }
        Catch{
            Write-Output "Could not download $(($_).ToUpper()) BIOS   - $($global:DriverFile.DriverFile)"
        }
    
        
    }
 

    

    



return "

                                
All files have been downloaded to $($global:Path)


"
}





if ($result -eq [System.Windows.Forms.DialogResult]::CANCEL)
{
    $form.Close()
    return
}


                        }
                        'False'{
                            $NumberArray = $Null
                            $NumberArray = @()

                            $global:ModelArray | %{

                                $number = "$($global:ModelArray.IndexOf($_))   -   $($_)"
                                $NumberArray += $number

                            }

                            
                        }




                    }
                    $NumberArray
                    $ModelsSelected = @()
                    $Selection = Read-Host -Prompt '


Please Choose the number of the model(s) you would like to download. 
("Comma or Space" Seperated if choosing multiple. You may also do a single range as such 0..25)
'
                    clear

                    if($Selection -match '(\d+\.\.\d+)'){
                        $Numbers = ($Selection).split('..')
                        $NumberRange = $Numbers[0]..$Numbers[1]
                        If($NumberRange.Count -gt 1){

                            Write-Output "
                        
                        
Downloading ( $($NumberRange.Count) ) BIOS Drivers
                        
                        
                        "
                        }
                        else{
                            Write-Output "
                        
                        
Downloading ( 1 ) BIOS Driver
                            
                            
                            "
                        
                        }
                        $NumberRange | %{
                            $ModelsSelected += $global:ModelArray[$_]
                                }
    
                                $ModelsSelected | %{
                                GetDriver
                                DriverVersion
                                DownloadPath
                                Write-Progress -Id 0 -Activity "   Downloading  $($ModelsSelected.Indexof($_)+1) of $($ModelsSelected.Count)     >      $(($_).ToUpper()) BIOS" -Status " "
                                Try{
                                    Download
                                    }
                                    Catch{
                                        Write-Output "Could not download $($global:DriverFile.DriverName)"
                                    }
    
                                }
                                return "


All files have been downloaded to $($global:Path)


"


                    }
                    else{
                    $Selection -split '\W' | %{
                        $ModelsSelected += $global:ModelArray[$_]
                            }

                            $ModelsSelected | %{
                            GetDriver
                            DriverVersion
                            DownloadPath
                            Write-Progress -Id 0 -Activity "   Downloading  $($ModelsSelected.Indexof($_)+1) of $($ModelsSelected.Count)     >      $(($_).ToUpper()) BIOS" -Status " "
                            Try{
                                Download
                                }
                                Catch{
                                    Write-Output "Could not download $($global:DriverFile.DriverName)"
                                }

                            }
                            return "

                                
All files have been downloaded to $($global:Path)


"
                        }
                }
        
        
        
        
              }
        
        
        
        
        
} # End of 'Get-DellBiosDriver' Switch Statement
        
        
            
         


















