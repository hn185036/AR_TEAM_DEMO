# 7.08.04 SVN Build

#--------------------------------Functions--------------------------$

# Establish Mapping and Connections
function Test-Admin
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
Function Map-File-Servers {
    #$password = ConvertTo-SecureString 'Compris123' -AsPlainText -Force;
    #$credential = New-Object System.Management.Automation.PSCredential("153.71.95.91\dev", $password);

    if(-Not (Test-Path "M:\")) {
        New-PSDrive -Name M -Root \\153.71.95.91\SUSDLG9000Waterloo\Microsoft -PSProvider FileSystem -Persist -Scope 'Global';
    }
    if(-Not (Test-Path "P:")) {
        New-PSDrive -Name P -Root \\153.71.95.91\SUSDLG9000Waterloo\CompDev -PSProvider FileSystem -Persist -Scope 'Global';
    }
    if(-Not (Test-Path "Q:")) {
        New-PSDrive -Name Q -Root \\153.71.95.91\SUSDLG9000Waterloo\QA -PSProvider FileSystem -Persist -Scope 'Global';
    }
    if(-Not (Test-Path "R:")) {
        New-PSDrive -Name R -Root \\153.71.95.91\SUSDLG9000Waterloo\SW-Updates  -PSProvider FileSystem -Persist -Scope 'Global';
    }
    if(-Not (Test-Path "S:")) {
        New-PSDrive -Name S -Root \\153.71.95.91\SUSDLG9000Waterloo\Software -PSProvider FileSystem -Persist -Scope 'Global';
    }
}

# Get Next Build Number
Function Get-Next-Build {
    $nextBuild = 0;

    for($index = 1; $index -le 999; $index++) {
        $posDirectory = "\\153.71.95.91\SUSDLG9000Waterloo\QA\WORKING\POS\7\7.08";
        if($index -lt 10) {
            $posDirectory = $posDirectory + "\04.0"  + $index;
        } else {
            $posDirectory = $posDirectory + "\04."  + $index;
        }

        if(-Not (Test-Path -Path $posDirectory) ) {
            $nextBuild = $index;
            break;
        }
    }

    if($nextBuild -ne 0) {
        if ($nextBuild -lt 10) {
            return "0$nextBuild";
        }else {
            return $nextBuild;
        }
    }
    else {
        ThrowError "The script could not find a build number";
        [System.Environment]::Exit(1);
    }
}

# Get Last Build Number
Function Get-Last-Build {
    $nextBuild = 0;

    for($index = 145; $index -le 999; $index++) {
        $posDirectory = "\\153.71.95.91\SUSDLG9000Waterloo\QA\WORKING\POS\9\9.01";
        if($index -lt 10) {
            $posDirectory = $posDirectory + "\00.0"  + $index;
        } else {
            $posDirectory = $posDirectory + "\00."  + $index;
        }

        if(-Not (Test-Path -Path $posDirectory) ) {
            $nextBuild = $index;
            break;
        }
    }

    if($nextBuild -ne 0) {
        $nextBuild = $nextBuild - 1;
        if ($nextBuild -lt 10) {
            return "0$nextBuild";
        }else {
            return $nextBuild;
        }
    }
    else {
        ThrowError "The script could not find a build number";
        exit 1;
    }
}

#Unregister and Register Threed
Function Do-Threed-Process {

    $filePathU = $Env:windir + "\system32\THREED32.OCX";
    $filePathR = $Env:windir + "\system32\THREED20.OCX";
    try {
        $regsvrpU =  Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/s /u $filePathU" -wait -NoNewWindow -PassThru
        $regsvrpR =  Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/s $filePathR" -wait -NoNewWindow -PassThru

        if($regsvrpU.ExitCode -ne 0) {
            Write-Error 'Unable to Unregister THREED32' -ErrorAction Stop
            exit 1;
        }
        if($regsvrpR.ExitCode -ne 0) {
            Write-Error 'Unable to register THREED20' -ErrorAction Stop
            exit 1;
        }
    }
    catch {
        Write-Error $_.Exception.Message -ErrorAction Stop
        exit 1;
    }
}

# Look for Error in Output to exit Jenkins
Function Look-For-Error-And-Exit ([String] $logPath){

    $res = Select-String -Path $logPath -Pattern "Build FAILED";

    if($res -ne $null)
    {
         exit 1;
    }

    #Search string "failed"
    $res = Select-String -Path $logPath -Pattern "failed";
    if ($res -ne $null)
    {
          #Count Result 
          $resCount = $res.Count;
          # (-gt is for greater than)
          if ($resCount -gt 1){
               #Loop the result
               foreach ($resObj in $res)
               {
                  #Split by comma (exp: "========== Rebuild All: 46 succeeded, 1 failed, 0 skipped ==========" )
                  $resItem =  $resObj -split ","
                  #Split by space (exp: " 1 failed" )
                  $resFail = $resItem[1] -split " "
                  #Get fail count 
                  $resFailCount = $resFail[1]
                  # (-ge is for greater than or equal)
                  if ( $resFailCount -ge 1 )
                  {
                    #Write-Output "==========  TEST ERROR ========== ";
                    exit 1;
                  }
                    
               }
          }
          else{
               #Split by comma (exp: "========== Rebuild All: 46 succeeded, 1 failed, 0 skipped ==========" )
               $resItem =  $res.Line -split ","
               #Split by space (exp: " 1 failed" )
               $resFail = $resItem[1] -split " "
               #Get fail count 
               $resFailCount = $resFail[1]
               # (-ge is for greater than or equal)
               if ( $resFailCount -ge 1 )
               {
                 #Write-Output "========== TEST ERROR ========== ";
                 exit 1;
               }
          }
    }


    #Get All Logs in .out file
    $content = Get-Content $logPath;
    $res = $content  -match [regex]::Escape("error(s)"); 

    if ($res -ne $null)
    {
          foreach ($resObj in $res)
          {
               #Split by comma (exp: "AllShared - 2 error(s), 1 warning(s)" )
               $resItem =  $resObj -split ","
               #Split by (-) (exp: " AllShared - 2 error(s)" )
               $resFail = ($resItem[0] -split "-").Trim();
               #Split by space (exp: " 2 error(s)"" 
               $resFailCount =  $resFail -split " "
                # (-ge is for greater than or equal)
               if ( $resFailCount[1] -ge 1 )
               {
                    #Write-Output "========== TEST ERROR ========== ";
                    exit 1;
               }
          }
    }
}


#BuildOperatorSDK
Function Build-Sdk{
    Set-Location -Path "W:\common\Components\Operator\SDK"
    cmd.exe "/c" BuildOperDataSdk.bat
}

Function Build-Header([String] $fVersion){
    if(-Not(Test-Path -Path "E:\7.08.04.$fVersion\HeaderBuilderOutput")) {
        New-Item -Path "E:\7.08.04.$fVersion\HeaderBuilderOutput" -ItemType Directory;
    }
}

Function Generate-HashValue([String] $program, [String] $dir, [string] $ver) {
    $TempDir = "C:\temp\MD5Temp\";
    $WorkPath = "Q:\WORKING\Setups\$dir\7\7.08\04.$ver"

    if(Test-Path -Path $tempDir) {
        Get-ChildItem $tempDir | Remove-Item -Recurse -Force
    }

    if(-Not(Test-Path -Path $tempDir)) {
        New-Item  -ItemType Directory -Path $tempDir
    }

    if(Test-Path "$WorkPath\Setup.iss") {
        Copy-Item -Path "$WorkPath\Setup.iss" -Destination $tempDir;
    }

    $programFile = "$WorkPath\70804$ver" + "$program" + "Program.MD5";
    $contentFile = "$WorkPath\70804$ver" + "$program" + "Contents.MD5";

    Copy-Item -Path "$WorkPath\$program.exe" -Destination $tempDir
    Set-Location -Path $TempDir;
    fsum.exe "*.*" > $programFile;
    Start-Sleep -Seconds 5.0
    cmd.exe "/c" "$program /x $program";
    Start-Sleep -Seconds 10.0
    Set-Location -Path "$TempDir\$program";
    fsum.exe "*.*" > $contentFile;
}
#---------------------------- Main Function --------------------------------#

if (Test-Admin) {
    Write-Host "Running script with administrator privileges" -ForegroundColor Yellow
}
else {
    Write-Host "Running script without administrator privileges" -ForegroundColor Red
}

# 7.08.04s Begin Scripts
Write-Output "==========  Mapping File Servers ========== ";
Map-File-Servers

#Get Build Number
Write-Output "==========  Get The Build Number To Use ========== ";

$newBuild = Get-Next-Build -NoNewWindow -Wait
$tipBuild = Get-Last-Build -NoNewWindow -Wait;
$newVersion = "7.08.04." + $newBuild;
$newPOSVFolder = "E:\7.08.04." + $newBuild;
$prevBuild = $newBuild - 1;

#Set POSVer and DevDrive Environment
[Environment]::SetEnvironmentVariable("POSVER", "7.08.04.$newBuild", [System.EnvironmentVariableTarget]::User)
[Environment]::SetEnvironmentVariable("DEVDRIVE", "E:", [System.EnvironmentVariableTarget]::User)

Write-Output "Currently Building : 7.08.04.$newBuild";

#Unregister ThreedOCX
Write-Output "Processing Threed OCX";
Do-Threed-Process

#CreateDirectory
Write-Output "Creating Directory $newPOSVFolder";

if(Test-Path -Path $newPOSVFolder) {
    Remove-Item $newPOSVFolder -Recurse -Force;
}
New-Item -Path $newPOSVFolder -ItemType Directory

#Download Repository
#Write-Output "Download SVN Repository"
Write-Output "Download Github Repository"

$env:SVN_USER = "aa230423";
$env:SVN_PWD = 'Rl71QRW0qIda5$tn1GDfP7E5AsjXqb';
$env:SVN_NUMBER = "ARENG-24269";

$repoUrl = "https://hn185036:073b1884c54f87e069370dbd644225f8ef6285c3@github.com/ncr-swt-hospitality/DEMO-AR-POS.git"

try {
    #svn.exe "checkout" "http://subversion.sweng.ncr.com/svn/repos/pa/ar/POS/branches/POS_70804" $newPOSVFolder "--username" $env:SVN_USER "--password" $env:SVN_PWD;
    Write-Output "Start Clone Github Repository"
    git clone $repoUrl $newPOSVFolder
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Stop
}

#Update POSVersion
Write-Output "========== Updating POS Version ========== ";
UpdateFileVersion.exe "$newPOSVFolder\common\version\posver.cpp" "/S$newVersion.00"
#svn.exe "commit" "$newPOSVFolder\$repoName\common\version\posver.cpp" "-m" "$args - $newVersion Build" "--username" $env:SVN_USER "--password" $env:SVN_PWD;
git add "$newPOSVFolder\WindowsAppCSharp\WindowsAppCSharp\WindowsAppCSharp.rc"
git commit -m "Update File Version WindowsAppCSharp.rc"


#Update EFT Version
Write-Output "========== Updating EFT Version ========== ";
UpdateFileVersion.exe "$newPOSVFolder\common\inc\eftver.rc" "/S$newVersion";
git add "$newPOSVFolder\common\inc\eftver.rc"
git commit -m "Update File Version eftver.rc"

#Git Push changes 
git push

#Drive Substitute
Write-Output "========== Substituing the Drives ========== "

#Delete Subst Drives
subst.exe "W:"  "/d"
subst.exe "I:"  "/d"
subst.exe "N:"  "/d"

subst.exe "W:" $newPOSVFolder
subst.exe "I:" "C:\3rdparty"
subst.exe "N:" "C:\MSVC"

#Delete Logs
Write-Output "========== Delete Old Logs ========== "
Remove-Item "$newPOSVFolder\*.out";

#Make Common Controls
Write-Output "========== Make Common Controls ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeCommonCtls.bat;
Look-For-Error-And-Exit("W:\MakeCommonCtls.out");

#Make Shared Devices
Write-Output "========== Make Shared Devices ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeSharedDevices.bat;
Look-For-Error-And-Exit("W:\MakeSharedDevices.out");

#Make POS Configuration VS 2010
Write-Output "========== Make POS Configuration VS2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakePOSConfigurationDataVS2010.bat;
Look-For-Error-And-Exit("W:\MakePOSConfigurationDataVS2010.out");

#Make GPOS
Write-Output "========== Make GPOS ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakeGpos.bat;
Look-For-Error-And-Exit("W:\MakeGpos.out");

#Make Editors
Write-Output "========== Make Editors ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeEditors.bat;
Look-For-Error-And-Exit("W:\MakeEditors.out");

#Make Editors VS2010
Write-Output "========== Make Editors 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\editors\MakeEditors.BAT;
Look-For-Error-And-Exit("W:\editors\MakeEditors.out");


#Make Editors Util VS2010
Write-Output "========== Make Editors Utils 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\editors\UTILS\MakeEditorUtils.bat;
Look-For-Error-And-Exit("W:\editors\UTILS\MakeEditorUtils.out");


#Make POS Dumps
Write-Output "========== Make Dumps ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\pos\DUMPS\MakePosDumps.bat;
Look-For-Error-And-Exit("W:\pos\DUMPS\PosDumps.out");


#Make Store Configuration
Write-Output "========== Make Store Configuration ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakeStoreConfiguration.bat;
Look-For-Error-And-Exit("W:\MakeStoreConfiguration.out");

#Make File Updater
Write-Output "========== Make File Updater ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeFileUpdater.bat;
Look-For-Error-And-Exit("W:\MakeFileUpdater.out");


#Make Communication Center
Write-Output "========== Make Communication Center ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeCommunicationCenter.bat;
Look-For-Error-And-Exit("W:\MakeCommunicationCenter.out");


#Make POS DB Service
Write-Output "========== Make POS DB Service ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakePosDbService.bat;
Look-For-Error-And-Exit("W:\PosDbService.out");


#Make POS RR Framework VS2010
Write-Output "========== Make POS RR Framework 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakePOSRRFrameworkVS2010.bat;
Look-For-Error-And-Exit("W:\MakePOSRRFrameworkVS2010.out");


#Make Commcenter Handler VS2010
Write-Output "========== Make Commcenter Handler 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakeCommCenterHandlersVS2010.bat;
Look-For-Error-And-Exit("W:\MakeCommCenterHandlersVS2010.out");

#Make POS DB Service VS 2010
Write-Output "========== Make POS DB Service VS 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakePosDbServiceVS2010.bat;
Look-For-Error-And-Exit("W:\MakePOSDbServiceVS2010.out");

#Make Kitchen
Write-Output "========== Make Kitchen ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeKitchen.bat;
Look-For-Error-And-Exit("W:\kit4257.out");

#Make Kitchen VS 2010
Write-Output "========== Make Kitchen VS 2010 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeKitchenVS2010.bat;
Look-For-Error-And-Exit("W:\MakeKitchenVS2010.out");

#Make POS Shared
Write-Output "========== Make POS Shared ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakePosShared.bat;
Look-For-Error-And-Exit("W:\PosShared.out");


subst.exe "J:"  "/d"
subst.exe "J:" "C:\sql-amws"

Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/s J:\3rdParty\EncDecPassword.dll" -wait -NoNewWindow -PassThru

#Make ActiveX
Write-Output "========== Make ActiveX ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeActiveX.bat;
Look-For-Error-And-Exit("W:\PosActiveX.out");
subst.exe "J:"  "/d"

#Make Security Drivers
Write-Output "========== Make Security Drivers ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeSecurityDrivers.bat;
Look-For-Error-And-Exit("W:\MakeSecurityDrivers.out");

#Make Security Drivers
Write-Output "========== Make Make Arms Interface Site5 ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeArmsInterfaceSite5.bat "7" "08" "04.$newBuild";
Look-For-Error-And-Exit("W:\PosArmsInterface.out");

#Make PHFW Utils
Write-Output "========== Make PHFW Utils ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakePHFWUtils.bat;
Look-For-Error-And-Exit("W:\compris.out");


#Make POS SQL Upgrade
Write-Output "========== Make POS SQL Upgrade ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakePosSqlUpgrade.bat $newVersion;
Look-For-Error-And-Exit("W:\MakePosSqlUpgrade.out");


#Make Compris QSR Monitor
Write-Output "========== Make Compris QSR Monitor ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeComprisQsrMonitor.bat;
Look-For-Error-And-Exit("W:\ComprisQsrMonitor.out");


#Make Applications
Write-Output "========== Make Applications ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeApplications.bat;
Look-For-Error-And-Exit("W:\MakeApplications.out");

#Make POS SQL Purge
Write-Output "========== Make POS SQL Purge ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakePosSqlPurge.bat;
Look-For-Error-And-Exit("W:\PosSqlPurge.out");

#Make Yum
Write-Output "========== Make Yum ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeYum.bat;
Look-For-Error-And-Exit("W:\MakeYum.out");

#Make XUI
Write-Output "========== Make XUI ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeXui.bat;
Look-For-Error-And-Exit("W:\Xui.out");

#Make the MobilePOS AssemblyInfo files Writeable
Write-Output "========== Make the MobilePOS AssemblyInfo files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\psx\src\MobilePOS\MobilePOS\Properties\AssemblyInfo.*" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\psx\src\MobilePOS\MobilePOS\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make the MobilePosConfig AssemblyInfo files Writeable
Write-Output "========== Make the MobilePosConfig AssemblyInfo files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\psx\src\MobilePOS\MobilePOSConfig\Properties\AssemblyInfo.*" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\psx\src\MobilePOS\MobilePOSConfig\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make the MpDevices.xml Files Writeable - MobilePosConfig
Write-Output "========== Make the MpDevices.xml Files Writeable - MobilePosConfig ========== ";
attrib.exe "-r" "$newPOSVFolder\psx\src\MobilePOS\MPM\Configuration\MPDevices.xml" "/s"

#Not Use
#Make MakeMobilePos
#Write-Output "========== Make MakeMobilePos ========== ";
#BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeMobilePos.bat;
#Look-For-Error-And-Exit("W:\MobilePos.out");

#Make Commcenter Manager
Write-Output "========== Make Commcenter Manager ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32CV10" W:\MakeCommCenterManager.bat;
Look-For-Error-And-Exit("W:\MakeCommCenterManager.out");

#Make the Online Ordering Setup.vdproj Files writeable
Write-Output "========== Make the Online Ordering Setup.vdproj Files writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\OnlineOrdering\Setup\Setup\Setup.vdproj" "/s"
updateDotNetSetupProjectVersion.exe "$newPOSVFolder\common\Components\OnlineOrdering\Setup\Setup\Setup.vdproj" "7" "08" "04" $newBuild

#Make the Online Assembly info files writeable
Write-Output "========== Make the Online Assembly files writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\OnlineOrdering\AlohaTakeOutInterface.RdfProxy\Properties\AssemblyInfo.cs" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\common\Components\OnlineOrdering\AlohaTakeOutInterface.RdfProxy\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make Online Ordering
Write-Output "========== Make Online Ordering ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32CV10" W:\MakeOnlineOrdering.bat;
Look-For-Error-And-Exit("W:\MakeOnlineOrdering.out");

#Make the CommCenter.Tender AssemblyInfo files Writeable
Write-Output "========== Make the CommCenter.Tender AssemblyInfo files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.Tender\Properties\AssemblyInfo.cs" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.Tender\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make the CommCenter.TenderViewer AssemblyInfo files Writeable
Write-Output "========== Make the CommCenter.TenderViewer AssemblyInfo files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderViewer\Properties\AssemblyInfo.cs" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderViewer\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make the CommCenter.TenderService AssemblyInfo files Writeable
Write-Output "========== Make the CommCenter.TenderViewer AssemblyInfo files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderService\Properties\AssemblyInfo.cs" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderService\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make the CommCenter.TenderSetup.vdproj Files Writeable
Write-Output "========== Make the CommCenter.TenderSetup.vdproj Files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\CommCenter.TenderSetup.vdproj " "/s"
updateDotNetSetupProjectVersion.exe "$newPOSVFolder\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\CommCenter.TenderSetup.vdproj" "7" "08" "04
" $newBuild

#Make Commcenter.TenderService
Write-Output "========== Make TenderService ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC10" W:\MakeCommCenter.TenderService.bat;
Look-For-Error-And-Exit("W:\MakeCommCenter.TenderService.out");

#Make ComprisIA Dll
Write-Output "========== Make ComprisIA Dll ========== ";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32VC6" W:\MakeComprisIADLL.bat;
Look-For-Error-And-Exit("W:\MakeComprisIADLL.out");


#Make the MakeARTranslatorVS2010 files Writeable
Write-Output "========== Make the MakeARTranslatorVS2010 files Writeable ========== ";
attrib.exe "-r" "$newPOSVFolder\common\Components\ComprisIA\ARTranslator\ARTranslator\Properties\AssemblyInfo.cs" "/s"
updateDotNetAssemblyInfoFileVersion.exe "$newPOSVFolder\common\Components\ComprisIA\ARTranslator\ARTranslator\Properties\AssemblyInfo.cs" "-set:$newVersion"

#Make AR Transalator 2010
Write-Output "========== Make AR Translator 2010 ==========";
BldAppSvn.bat "$env:SVN_USER" "$env:SVN_PWD" "$env:SVN_NUMBER" "E" "$newVersion" "32CV10" W:\MakeARTranslatorVS2010.bat;
Look-For-Error-And-Exit("W:\\MakePOSConfigurationDataVS2010.out");

#Sign All
Write-Output "========== Sign All ==========";
W:\SignAll.cmd

#Remove Q:Working DIR
Write-Output "========== Copying to Q Working ==========";
if((Test-Path "Q:\Working\POS\7\7.08\04.$newBuild")) {
    Remove-Item -Path "Q:\Working\POS\7\7.08\04.$newBuild" -Recurse;
}

W:\COPYALLQ.BAT "7" "08" "04.$newBuild";

#Copy the Verifone EFT Monitor Files to Tip Build
Write-Output "========== Copy EFT Verifone Monitor Files ==========";
$pathTip = "Q:\WORKING\POS\9\9.01\00.$tipBuild\Eft\EftMon.*";
$copyTo = "Q:\WORKING\POS\7\7.08\04.$newBuild\EFT";
Copy-Item -Path $pathTip -Destination $copyTo;


#Copy or Overwrite version independent DLL's
Write-Output "========== Copy or Overwrite version independent DLL's ==========";
W:\CopyAllVersionIndependentDLLQ.BAT "7" "08" "04.$newBuild" "9" "01" "00.$tipBuild";

#Create the POS Setup Programs
Write-Output "========== Create the POS Setup Program ==========";
svn.exe "update" "C:\Compris Setups" "--force"
svn.exe "update" "C:\Program Files (x86)\Wise Installation System\Include" "--force"

xcopy.exe "C:\Compris Setups\setup.iss" "Q:\WORKING\Setups" "/r" "/y"

if(-Not(Test-Path "Q:\Working\Setups\POS\7\7.08\03.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\POS\7\7.08\03.$newBuild" -ItemType Directory;  
}

if(-Not(Test-Path "Q:\Working\Setups\MobilePos\7\7.08\03.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\MobilePos\7\7.08\03.$newBuild" -ItemType Directory;
}

#Not Use
#svn.exe "update" "$newPOSVFolder\psx\src\MobilePOS\MPosSetup\Release" "--force"
#Copy-Item -Path "W:\psx\src\MobilePOS\MPosSetup\Release\*" -Destination "Q:\Working\Setups\MobilePos\7\7.08\03.$newBuild" -recurse -Force

#Establish Setup Path
Write-Output "========== Establish Setup Path ==========";

$setupPath = "W:\Compris Setups";
$tempDir = "C:\temp\MD5Temp";
$wise32 = "C:\Program Files (x86)\Wise Installation System\Wise32.exe";

#Initialize Setup procedure
Write-Output "========== Initialize GPOS Setup procedure ==========";
if(Test-Path "$setupPath\Setup.exe") {
    Remove-Item -Path "$setupPath\Setup.exe";
}


xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\POS\7\7.08\04.$newBuild" "/r" "/y"
xcopy.exe "C:\tools\DigitalSignature\NCRAdvancedRestaurantRoot.cer" "Q:\Working\Setups\POS\7\7.08\04.$newBuild" "/r" "/y"

#Creating POS Setup
Write-Output "========== Creating POS Setup Installer ==========";
&$wise32 "/c" "/s" "$setupPath\POS and POSDBService 7.02.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\Setup.exe") ) {
    Write-Output "Error Creating GPOS Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\setup.exe"
    Copy-Item -Path "$setupPath\Setup.exe" -Destination "Q:\Working\Setups\POS\7\7.08\04.$newBuild"
}

#Perform Hash Values Generation
Write-Output "========== Perform Hash Values Generation ==========";
Generate-HashValue "Setup" "POS" "$newBuild" ;

#Creating POS Upgrade
Write-Output "========== Creating POS Upgrade Setup ==========";

#Initialize Setup procedure
Write-Output "========== Initialize GPOS Upgrade procedure ==========";
if(Test-Path "$setupPath\PosUp.exe") {
    Remove-Item -Path "$setupPath\PosUp.exe";
}

&$wise32 "/c" "/s" "$setupPath\Upgrade POS and POSDBService 7.02.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\PosUp.exe") ) {
    Write-Output "Error Creating GPOS Upgrade Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\PosUp.exe"
    Copy-Item -Path "$setupPath\PosUp.exe" -Destination "Q:\Working\Setups\POS\7\7.08\04.$newBuild"
}

#Perform Hash Values Generation
Write-Output "========== Perform Hash Values Generation ==========";
Generate-HashValue "POSUp" "POS" "$newBuild" ;


#Create HDS Setup Program
Write-Output "========== Create HDS Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\HDS\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\HDS\7\7.08\04.$newBuild" -ItemType Directory;
}

xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\HDS\7\7.08\04.$newBuild" "/r" "/y"

#Initialize HDS Setup procedure
Write-Output "========== Initialize HDS Setup procedure ==========";
if(Test-Path "$setupPath\Setup.exe") {
    Remove-Item -Path "$setupPath\Setup.exe";
}

xcopy.exe "C:\tools\DigitalSignature\NCRAdvancedRestaurantRoot.cer" "Q:\Working\Setups\HDS\7\7.08\04.$newBuild" "/r" "/y"

#Creating HDS Setup
Write-Output "========== Creating HDS Setup Installer ==========";
&$wise32 "/c" "/s" "$setupPath\HomeDelivery 6.01.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" "/d_POINT_=04"  | Wait-Process

if( -Not (Test-Path "$setupPath\Setup.exe") ) {
    Write-Output "Error Creating HDS Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\Setup.exe"
    Copy-Item -Path "$setupPath\Setup.exe" -Destination "Q:\Working\Setups\HDS\7\7.08\04.$newBuild"
}

#Initialize HDS Upgrade procedure
Write-Output "========== Initialize HDS Upgrade procedure ==========";
if(Test-Path "$setupPath\HDSUp.exe") {
    Remove-Item -Path "$setupPath\HDSUp.exe";
}

#Creating HDS Upgrade
Write-Output "========== Creating HDS Upgrade Installer ==========";
&$wise32 "/c" "/s" "$setupPath\Upgrade HomeDelivery 6.01.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" "/d_POINT_=04"  | Wait-Process

if( -Not (Test-Path "$setupPath\HDSUp.exe") ) {
    Write-Output "Error Creating HDS Upgrade Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\HDSUp.exe"
    Copy-Item -Path "$setupPath\HDSUp.exe" -Destination "Q:\Working\Setups\HDS\7\7.08\04.$newBuild"
}

#Create EFT32 Verifone Client/Server Setup Program
Write-Output "========== Create EFT32 Verifone Client/Server Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\EFT\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\EFT\7\7.08\04.$newBuild" -ItemType Directory;
}

xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\EFT\7\7.08\04.$newBuild" "/r" "/y"

#Initialize EFT Verifone procedure
Write-Output "========== Initialize EFT Verifone procedure ==========";
if(Test-Path "$setupPath\Setup.exe") {
    Remove-Item -Path "$setupPath\Setup.exe";
}

#Creating EFT Verifone
Write-Output "========== Creating EFT Verifone Installer ==========";
&$wise32 "/c" "/s" "$setupPath\Verifone.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\Setup.exe") ) {
    Write-Output "Error Creating EFT Verifone Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\Setup.exe"
    Copy-Item -Path "$setupPath\Setup.exe" -Destination "Q:\Working\Setups\EFT\7\7.08\04.$newBuild"
}

#Perform Hash Values Generation
Write-Output "========== Perform Hash Values Generation ==========";
Generate-HashValue "Setup" "EFT" "$newBuild" ;

#Initialize Verifone EFT Upgrade procedure
Write-Output "========== Initialize Verifone EFT Upgrade procedure ==========";
if(Test-Path "$setupPath\Verifoneup.exe") {
    Remove-Item -Path "$setupPath\Verifoneup.exe";
}

#Create EFT Verifone Upgrade
Write-Output "========== Creating EFT Verifone Upgrade Installer ==========";
&$wise32 "/c" "/s" "$setupPath\UpgradeVerifone.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\Verifoneup.exe") ) {
    Write-Output "Error Creating EFT Verifone Upgrade Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\Verifoneup.exe"
    Copy-Item -Path "$setupPath\Verifoneup.exe" -Destination "Q:\Working\Setups\EFT\7\7.08\04.$newBuild"
}

#Perform Hash Values Generation
Write-Output "========== Perform Hash Values Generation ==========";
Generate-HashValue "Verifoneup" "EFT" "$newBuild";


#Initialize NCR UK EFT AuthEng procedure
Write-Output "========== Initialize  NCR UK EFT AuthEng procedure ==========";
if(Test-Path "$setupPath\aesetup.exe") {
    Remove-Item -Path "$setupPath\aesetup.exe";
}

#Create NCR UK EFT Autheng
Write-Output "========== Creating NCR UK EFT Autheng Installer ==========";
&$wise32 "/c" "/s" "$setupPath\NCR UK Server Only.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\aesetup.exe") ) {
    Write-Output "Error Creating NCR UK EFT Autheng Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\aesetup.exe"
    Copy-Item -Path "$setupPath\AEsetup.exe" -Destination "Q:\Working\Setups\EFT\7\7.08\04.$newBuild"
}

#Create ComprisIA and AR Translator
Write-Output "========== Create ComprisAI and AR Translator ==========";
if(-Not(Test-Path "Q:\Working\Setups\ComprisIA\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\ComprisIA\7\7.08\04.$newBuild" -ItemType Directory;
}

#Initialize ComprisIA and AR Translator
Write-Output "========== Initialize  NCR UK EFT AuthEng procedure ==========";
if(Test-Path "$setupPath\ComprisIA.exe") {
    Remove-Item -Path "$setupPath\ComprisIA.exe";
}

#Create ComprisIA Installer
Write-Output "========== Creating ComprisIA Installer ==========";
&$wise32 "/c" "/s" "$setupPath\ComprisIA.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\ComprisIA.exe") ) {
    Write-Output "Error Creating ComprisIA Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\ComprisIA.exe"
    Copy-Item -Path "$setupPath\ComprisIA.exe" -Destination "Q:\Working\Setups\ComprisIA\7\7.08\04.$newBuild"
}

#Initialize TLOGXFormer
Write-Output "========== Initialize TLOGXFormer procedure ==========";
if(Test-Path "$setupPath\TLXSetup.exe") {
    Remove-Item -Path "$setupPath\TLXSetup.exe";
}


#Create TLOGXFormer Installer
Write-Output "========== Creating TLOGXFormer Installer ==========";
&$wise32 "/c" "/s" "$setupPath\TLOGXForm.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\TLXSetup.exe") ) {
    Write-Output "Error Creating TLOGXFormer Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\TLXSetup.exe"
    Copy-Item -Path "$setupPath\TLXSetup.exe" -Destination "Q:\Working\Setups\POS\7\7.08\04.$newBuild"
}


#Create Communication Center Setup Program
Write-Output "========== Create Communication Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild" -ItemType Directory;
}

xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild" "/r" "/y"

#Initialize Commcenter
Write-Output "========== Initialize Communication Center Setup procedure ==========";
if(Test-Path "$setupPath\CommCenterSetup.exe") {
    Remove-Item -Path "$setupPath\CommCenterSetup.exe";
}

xcopy.exe "C:\tools\DigitalSignature\NCRAdvancedRestaurantRoot.cer" "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild" "/r" "/y"

Write-Output "========== Creating Communication Center Installer ==========";
&$wise32 "/c" "/s" "$setupPath\Commcenter.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\CommCenterSetup.exe") ) {
    Write-Output "Error Creating Communication Center Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\CommCenterSetup.exe"
    Copy-Item -Path "$setupPath\CommCenterSetup.exe" -Destination "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild"
}

#Initialize Commcenter Upgrade
Write-Output "========== Initialize Communication Center Upgrade procedure ==========";
if(Test-Path "$setupPath\CommCenterUp.exe") {
    Remove-Item -Path "$setupPath\CommCenterUp.exe";
}

Write-Output "========== Creating Communication Center Upgrade Installer ==========";
&$wise32 "/c" "/s" "$setupPath\Upgrade Commcenter.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POINT_=04" "/d_POS_BUILD_=04.$newBuild" "/d_SHARED_BUILD_=00.$newBuild" "/d_TIP_MAJOR_=9" "/d_TIP_MINOR_=01" "/d_TIP_POS_BUILD_=00.$tipBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\CommCenterUp.exe") ) {
    Write-Output "Error Creating Communication Center Upgrade Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\CommCenterUp.exe"
    Copy-Item -Path "$setupPath\CommCenterUp.exe" -Destination "Q:\Working\Setups\CommCenter\7\7.08\04.$newBuild"
}

#Initialize Compris QSR Monitor Setup Program
Write-Output "========== Initialize Compris QSR Monitor Setup  procedure ==========";
if(Test-Path "$setupPath\ComprisQSRMonitorSetup.exe") {
    Remove-Item -Path "$setupPath\ComprisQSRMonitorSetup.exe";
}

Write-Output "========== Creating Compris QSR Monitor Setup Installer ==========";
&$wise32 "/c" "/s" "$setupPath\ComprisQSRMonitor.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\ComprisQSRMonitorSetup.exe") ) {
    Write-Output "Error Creating TLOGXFormer Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\ComprisQSRMonitorSetup.exe"
    Copy-Item -Path "$setupPath\ComprisQSRMonitorSetup.exe" -Destination "Q:\Working\Setups\POS\7\7.08\04.$newBuild"
}


#Create Online Ordering Setup Program
Write-Output "========== Create Online Ordering Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\OnlineOrdering\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\OnlineOrdering\7\7.08\04.$newBuild" -ItemType Directory;
}

#Initialize Online Ordering Setup Program
Write-Output "========== Initialize Online Ordering Setup procedure ==========";
if(Test-Path "$setupPath\OnlineOrderingSetup.exe") {
    Remove-Item -Path "$setupPath\OnlineOrderingSetup.exe";
}

&"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "W:\common\Components\OnlineOrdering\Setup\Setup\Release\SetupOnlineOrdering.msi"
Copy-Item -Path "W:\common\Components\OnlineOrdering\Setup\Setup\Release\SetupOnlineOrdering.msi" -Destination "Q:\Working\Setups\OnlineOrdering\7\7.08\04.$newBuild"

Write-Output "========== Creating Online Ordering Setup Installer ==========";
&$wise32 "/c" "/s" "$setupPath\OnlineOrderingSetup.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\OnlineOrderingSetup.exe") ) {
    Write-Output "Error Creating Online Ordering Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\OnlineOrderingSetup.exe"
    Copy-Item -Path "$setupPath\OnlineOrderingSetup.exe" -Destination "Q:\Working\Setups\OnlineOrdering\7\7.08\04.$newBuild"
    xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\OnlineOrdering\7\7.08\04.$newBuild" "/r" "/y"
}

#Create CommCenter Tender Service Program
Write-Output "========== Create Online Ordering Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\CommCenter.TenderService\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\CommCenter.TenderService\7\7.08\04.$newBuild" -ItemType Directory;
}

&"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "W:\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\Release\CommCenter.TenderSetup.msi"
Copy-Item -Path "W:\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\Release\CommCenter.TenderSetup.msi" -Destination "Q:\Working\Setups\CommCenter.TenderService\7\7.08\04.$newBuild"

&"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "W:\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\Release\setup.exe"
Copy-Item -Path "W:\common\Components\CommunicationCenter\CommCenter.TenderService\CommCenter.TenderSetup\Release\setup.exe" -Destination "Q:\Working\Setups\CommCenter.TenderService\7\7.08\04.$newBuild"


#Create AirTag Setup Program
Write-Output "========== Create AirTag Setup Program ==========";
if(-Not(Test-Path "Q:\Working\Setups\AirTag\7\7.08\04.$newBuild")) {
    New-Item -Path "Q:\Working\Setups\AirTag\7\7.08\04.$newBuild" -ItemType Directory;
}

#Initialize AirTag Setup Program
Write-Output "========== Initialize AirTag Setup procedure ==========";
if(Test-Path "$setupPath\AirTag.exe") {
    Remove-Item -Path "$setupPath\AirTag.exe";
}

Write-Output "========== Creating AirTag Setup Installer ==========";
&$wise32 "/c" "/s" "$setupPath\AirTag.wse" "/d_MAJOR_=7" "/d_MINOR_=08" "/d_POS_BUILD_=04.$newBuild" | Wait-Process

if( -Not (Test-Path "$setupPath\AdvancedRestaurantAirTagSetup.exe") ) {
    Write-Output "Error Creating AirTag Installer. Please check if all necessary files are present.";
    exit 1
} else {
    &"C:\TOOLS\DigitalSignature\ARSignTool.cmd" "$setupPath\AdvancedRestaurantAirTagSetup.exe"
    Copy-Item -Path "$setupPath\AdvancedRestaurantAirTagSetup.exe" -Destination "Q:\Working\Setups\AirTag\7\7.08\04.$newBuild"
    xcopy.exe "$setupPath\Setup.iss" "Q:\Working\Setups\AirTag\7\7.08\04.$newBuild" "/r" "/y"
}

#Build Operator SDk
Write-Output "========== Build Operator SDK ==========";
Build-Sdk
Copy-Item -Path "W:\common\Components\Operator\SDK\OperDataSdk.7.08.04.$newBuild.zip" -Destination "Q:\Working\Setups\POS\7\7.08\04.$newBuild"

#Run the Difference Report Batch File
Write-Output "========== Run the Difference Report Batch File ==========";
&C:\tools\RelCmpSvnJenkins.bat "7" "08" "04" "$newBuild" "$prevBuild";
$diffReport = "7.08.04.$newBuild" + "g.txt";
$fileNameDiff = "$newVersion File Differences Report.txt";
Copy-Item -Path "C:\temp\$diffReport" -Destination "Q:\Working\POS\7\7.08\04.$newBuild\$fileNameDiff"

svn.exe "cp" $newPOSVFolder "http://subversion.sweng.ncr.com/svn/repos/pa/ar/POS/tags/POS_70804/$newVersion" "-m" "$args - $newVersion tag created" "--username" $env:SVN_USER "--password" $env:SVN_PWD "--parents"

#Creating Zip File
Write-Output "========== Creating Yum Header Zip ==========";

Set-Location -Path "W:\HeaderBuilderOutput"
PKZIP25.EXE "-add" "-path=current" "-silent" "W:\YumHeaderDistribution70804$newBuild.zip" "Yum*.*" "*.idl"
Copy-Item -Path "W:\YumHeaderDistribution70804$newBuild.zip" -Destination "Q:\working\setups\POS\7\7.08\04.$newBuild"

#Creating Zip File
Write-Output "========== Creating Zip File ==========";

Set-Location "C:\temp\7.08"
svn.exe "export" "http://subversion.sweng.ncr.com/svn/repos/pa/ar/POS/tags/POS_70804/$newVersion" "$newVersion"
7z.exe "a" "-sdel" "-t7z" "-m0=lzma2" "-aoa" "-mx=9" "-mfb=64" "-md=32m" "-ms=on" "-mmt=on" "70804$newBuild.7z" ".\$newVersion\*"
cmd.exe "/c" "rd" "/s" "/q" "$newVersion"

Write-Output "========== Copy source code to Posstuff ==========";
Copy-Item -Path "C:\temp\7.08\70804$newBuild.7z" -Destination "P:\posstuff\Sandbox Archives\POS Source\7.08"

#cleanup w: to reclaim hard disk space
TortoiseProc.exe "/command:cleanup" "/breaklocks" "/noui" "noprogressui" "/nodialog" "/revert" "/delunversioned" "/delignored" '/path:"W:\"' "2>NUL"

Write-Output "========== Updating jira tickets ==========";

$jira = &"C:\TOOLS\JiraCLI\jira.bat" --server http://jira.ncr.com --user $env:SVN_USER --password $env:SVN_PWD --action getIssueList --search "project = ARENG AND (fixVersion = \`"POS 7.08.04\`") AND \`"States / Sub States\`" in cascadeOption(11243, 11253) ORDER BY key DESC"

$countJira = 0;
$strMessage = '<b>JIRA TRACKING:</b><br>';

for($indexJi=0; $indexJi -lt ( $jira.length - 1); $indexJi++)
{
    if($indexJi -gt 1) 
    {  
       $jArr = $jira[$indexJi] -split '","';

       if($jArr[0].Length -gt 1)
       {
            $jNum = $jArr[0].Substring(1);

            if($jNum.Length -gt 5 -And $jNum.Substring(0,5) -eq "ARENG")
            {
                $jDes = $jArr[20];KENshin553@@@kenshin553@@@


                $countJira++;

                $strMessage += "&nbsp;&nbsp;&nbsp;&nbsp $countJira. $jNum - $jDes";
                $strMessage += "<br>"
            }
        }
    }
}
Write-Output $strMessage;

&"C:\TOOLS\JiraCLI\jira.bat" --server http://jira.ncr.com --user $env:SVN_USER --password $env:SVN_PWD --action runFromIssueList --search "project = ARENG AND (fixVersion = \`"POS 7.08.04\`") AND \`"States / Sub States\`" in cascadeOption(11243, 11253) ORDER BY key DESC" --common "--action updateIssue --issue @issue@ --custom customfield_10060:$newVersion --comment \`"POS_70804 Build Complete - $newVersion\`" --field customfield_10242 --values 11243,11254 --asCascadeSelect"

Write-Output "Build Complete - POS_70804 TEST";
Write-Output "Build Successful: 7.08.04.$newBuild";
