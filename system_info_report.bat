@echo off
setlocal enabledelayedexpansion
:: System Information Report Script - Universal (Windows 7 to Windows 11)
:: Run this script as Administrator for best results

echo ====================================================================
echo               SYSTEM INFORMATION REPORT
echo ====================================================================
echo Generated on: %date% at %time%
echo ====================================================================
echo.

:: Detect if WMIC is available (Legacy Mode)
set USE_WMIC=0
wmic bios get serialnumber >nul 2>&1
if !errorlevel!==0 (
    set USE_WMIC=1
    echo [Detection: Using WMIC - Legacy Mode for compatibility]
) else (
    echo [Detection: Using PowerShell - Modern Mode]
)
echo.

:: BIOS Serial Number
echo [1] BIOS SERIAL NUMBER
echo ----------------------------------------------------------------
if "!USE_WMIC!"=="1" (
    for /f "skip=1 delims=" %%a in ('wmic bios get serialnumber 2^>nul') do (
        if not defined BIOS_PRINTED (
            if not "%%a"=="" (
                echo %%a
                set BIOS_PRINTED=1
            )
        )
    )
) else (
    for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_BIOS).SerialNumber"`) do echo %%a
)
echo.

:: Disk Drive Information
echo [2] DISK DRIVE INFORMATION
echo ----------------------------------------------------------------
echo Processing disk information...
echo.

set "DISK_PRINTED=0"

if "!USE_WMIC!"=="1" (
    REM Parse WMIC key=value lines silently
    for /f "tokens=1* delims==" %%A in ('wmic diskdrive get model,serialnumber,size /format:list 2^>nul ^| findstr /R /C:".*"') do (
        set "key=%%A"
        set "value=%%B"
        set "key=!key: =!"
        for /f "tokens=* delims= " %%V in ("!value!") do set "value=%%V"

        if /i "!key!"=="Model" (
            set "model=!value!"
        ) else if /i "!key!"=="SerialNumber" (
            set "serial=!value!"
        ) else if /i "!key!"=="Size" (
            set "size=!value!"
            if defined model (
                if "!serial!"=="" set "serial=N/A"
                if "!size!"=="" (
                    set "sizeGB=0"
                ) else (
                    set /a sizeGB=!size!/1073741824 2>nul
                )
                echo Model: !model!
                echo Serial Number: !serial!
                echo Size: !sizeGB! GB
                echo --------------------------------
                set "DISK_PRINTED=1"
            )
            REM reset for next disk entry
            set "model="
            set "serial="
            set "size="
            set "sizeGB="
        )
    )

    if "!DISK_PRINTED!"=="1" (
        goto :DISK_DONE
    )
)

REM PowerShell fallback (silent)
for /f "usebackq tokens=1,2,* delims=," %%a in (`
    powershell -NoProfile -Command "Get-PhysicalDisk 2>$null | ForEach-Object { $m = if ($_.Model) {$_.Model} else {'N/A'}; $s = if ($_.SerialNumber) {$_.SerialNumber} else {'N/A'}; $sz = if ($_.Size) {[math]::Round($_.Size/1GB,2)} else {0}; Write-Output ('{0},{1},{2}' -f $m,$s,$sz) }"
`) do (
    set "model=%%a"
    set "serial=%%b"
    set "size=%%c"
    if "!model!"=="" set "model=N/A"
    if "!serial!"=="" set "serial=N/A"
    if "!size!"=="" set "size=0"
    set "size=!size: =!"
    echo Model: !model!
    echo Serial Number: !serial!
    echo Size: !size! GB
    echo ---------------------------------
    set "DISK_PRINTED=1"
)

:DISK_DONE
if "!DISK_PRINTED!"=="0" (
    echo No disk drives found or unable to retrieve disk information.
    echo --------------------------------
)

echo.

:: Operating System Information
echo [3] OPERATING SYSTEM INFORMATION
echo ----------------------------------------------------------------
for /f "tokens=2 delims=:" %%a in ('systeminfo ^| findstr /B /C:"OS Name"') do echo Installed OS:%%a
for /f "tokens=2 delims=:" %%a in ('systeminfo ^| findstr /B /C:"OS Version"') do echo OS Version:%%a
for /f "tokens=2* delims=:" %%a in ('systeminfo ^| findstr /B /C:"Original Install Date"') do echo OS Install Date:%%a:%%b
for /f "tokens=2 delims=:" %%a in ('systeminfo ^| findstr /B /C:"BIOS Version"') do echo BIOS Version:%%a
echo.

:: Administrator Account Status
echo [4] ADMINISTRATOR ACCOUNT STATUS
echo ----------------------------------------------------------------
net user administrator 2>nul | findstr /C:"Account active" >nul
if !errorlevel!==0 (
    for /f "tokens=3" %%a in ('net user administrator ^| findstr /C:"Account active"') do (
        if /i "%%a"=="Yes" (
            echo Administrator Account: ENABLED
        ) else (
            echo Administrator Account: DISABLED
        )
    )
) else (
    echo Administrator Account: User not found or access denied
)
echo.

:: Group Policy Status
echo [5] GROUP POLICY STATUS
echo ----------------------------------------------------------------
for /f "tokens=*" %%a in ('whoami') do set "currentuser=%%a"
echo Checking Group Policy for user: %currentuser%
echo.
gpresult /r 2>nul | findstr /C:"applied Group Policy objects" >nul
if !errorlevel!==0 (
    echo Group Policy: ENABLED and Applied
    echo.
    echo Applied Group Policies:
    gpresult /r 2>nul | findstr /C:"Applied Group Policy"
) else (
    gpresult /r 2>nul >nul
    if !errorlevel!==0 (
        echo Group Policy: AVAILABLE but No policies applied
        echo Note: This is likely a standalone system with no Group Policy Objects configured
    ) else (
        echo Group Policy: Access denied - Run as Administrator
    )
)
echo.

:: Firewall Status
echo [6] Firewall Authentication (IPsec):
echo ----------------------------------------------------------------

:: Initialize a flag
set "FW_AUTH_ENABLED=0"

:: Loop through the netsh output and look for any rule names
for /f "usebackq tokens=*" %%A in (`netsh advfirewall consec show rule name=all 2^>nul`) do (
    echo %%A | findstr /I "Rule Name" >nul
    if !errorlevel! equ 0 set "FW_AUTH_ENABLED=1"
)

:: Print result based on flag
if !FW_AUTH_ENABLED! equ 1 (
    echo Firewall Authentication: ENABLED
    echo IPsec connection security rules are present.
) else (
    echo Firewall Authentication: NOT ENABLED
    echo No IPsec connection security rules found.
)
echo.


:: Social Media Websites Connectivity Check
echo [7] SOCIAL MEDIA WEBSITES CONNECTIVITY CHECK
echo ----------------------------------------------------------------
echo Testing connectivity to popular social media websites...
echo This may take a few seconds...
echo.

:: Test Facebook
echo Testing Facebook...
ping -n 1 -w 2000 www.facebook.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Facebook: WORKING - Website is accessible
) else (
    echo [XX] Facebook: NOT WORKING - Cannot reach website
)

:: Test Instagram
echo Testing Instagram...
ping -n 1 -w 2000 www.instagram.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Instagram: WORKING - Website is accessible
) else (
    echo [XX] Instagram: NOT WORKING - Cannot reach website
)

:: Test Twitter/X
echo Testing Twitter/X...
ping -n 1 -w 2000 www.twitter.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Twitter/X: WORKING - Website is accessible
) else (
    echo [XX] Twitter/X: NOT WORKING - Cannot reach website
)

:: Test LinkedIn
echo Testing LinkedIn...
ping -n 1 -w 2000 www.linkedin.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] LinkedIn: WORKING - Website is accessible
) else (
    echo [XX] LinkedIn: NOT WORKING - Cannot reach website
)

:: Test YouTube
echo Testing YouTube...
ping -n 1 -w 2000 www.youtube.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] YouTube: WORKING - Website is accessible
) else (
    echo [XX] YouTube: NOT WORKING - Cannot reach website
)

:: Test TikTok
echo Testing TikTok...
ping -n 1 -w 2000 www.tiktok.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] TikTok: WORKING - Website is accessible
) else (
    echo [XX] TikTok: NOT WORKING - Cannot reach website
)

:: Test WhatsApp Web
echo Testing WhatsApp Web...
ping -n 1 -w 2000 web.whatsapp.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] WhatsApp Web: WORKING - Website is accessible
) else (
    echo [XX] WhatsApp Web: NOT WORKING - Cannot reach website
)

:: Test Reddit
echo Testing Reddit...
ping -n 1 -w 2000 www.reddit.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Reddit: WORKING - Website is accessible
) else (
    echo [XX] Reddit: NOT WORKING - Cannot reach website
)

:: Test Snapchat
echo Testing Snapchat...
ping -n 1 -w 2000 www.snapchat.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Snapchat: WORKING - Website is accessible
) else (
    echo [XX] Snapchat: NOT WORKING - Cannot reach website
)

:: Test Pinterest
echo Testing Pinterest...
ping -n 1 -w 2000 www.pinterest.com >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Pinterest: WORKING - Website is accessible
) else (
    echo [XX] Pinterest: NOT WORKING - Cannot reach website
)

echo.
echo General Internet Connectivity Test:
ping -n 1 -w 2000 8.8.8.8 >nul 2>&1
if !errorlevel!==0 (
    echo [OK] Internet Connection: ACTIVE - Google DNS reachable
) else (
    echo [XX] Internet Connection: NO CONNECTION or Limited
)
echo.

:: USB Storage Devices
echo [8] USB STORAGE DEVICES HISTORY
echo ----------------------------------------------------------------
echo USB devices that have been connected to this computer:
echo.
reg query HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR /s 2>nul | findstr "FriendlyName" >nul
if !errorlevel!==0 (
    for /f "tokens=2,*" %%a in ('reg query HKLM\SYSTEM\CurrentControlSet\Enum\USBSTOR /s 2^>nul ^| findstr "FriendlyName"') do (
        echo - %%b
    )
) else (
    echo No USB storage devices found in registry or access denied
)
echo.

:: Windows Time Service Status
echo [9] WINDOWS TIME SERVICE STATUS
echo ----------------------------------------------------------------
w32tm /query /status 2>nul
if !errorlevel! neq 0 (
    echo.
    echo Windows Time Service: NOT RUNNING or NOT CONFIGURED
    echo Tip: Start the service with: net start w32time
) else (
    echo Time Service: RUNNING and Active
)
echo.

:: Network Configuration - IPv4 Address (Ethernet and Wireless Only)
echo [10] NETWORK CONFIGURATION - IPv4 ADDRESS
echo ----------------------------------------------------------------
echo Physical Network Adapters (Ethernet and Wireless):
echo.

set ADAPTER_FOUND=0
set READING_ADAPTER=0
set WAITING_GW=0

ipconfig /all > "%TEMP%\ipconfig_temp.txt"

for /f "usebackq tokens=*" %%a in ("%TEMP%\ipconfig_temp.txt") do (
    set "line=%%a"
    
    REM Check if this is a new adapter line
    echo !line! | findstr /C:"adapter" >nul
    if !errorlevel!==0 (
        REM Print previous adapter if it had IPv4
        if !HAS_IPV4!==1 (
            echo Adapter: !TEMP_ADAPTER!
            echo   IPv4: !TEMP_IPV4!
            if not "!TEMP_MASK!"=="" echo   Subnet Mask: !TEMP_MASK!
            if not "!TEMP_GW!"=="" echo   Default Gateway: !TEMP_GW!
            echo.
            set ADAPTER_FOUND=1
        )
        
        set READING_ADAPTER=0
        set WAITING_GW=0
        set CURRENT_ADAPTER=!line!
        
        REM Check if we should process this adapter
        echo !line! | findstr /I /C:"VMware" /C:"VirtualBox" /C:"Hyper-V" /C:"Virtual" /C:"TAP-" /C:"Loopback" >nul
        if !errorlevel! neq 0 (
            echo !line! | findstr /I /C:"Ethernet" /C:"Wireless" /C:"Wi-Fi" >nul
            if !errorlevel!==0 (
                set READING_ADAPTER=1
                set TEMP_ADAPTER=!line!
                set HAS_IPV4=0
                set TEMP_IPV4=
                set TEMP_MASK=
                set TEMP_GW=
            )
        )
    )
    
    REM Collect data if we're reading this adapter
    if !READING_ADAPTER!==1 (
        REM Get IPv4 Address
        echo !line! | findstr /C:"IPv4" >nul
        if !errorlevel!==0 (
            echo !line! | findstr /C:":" >nul
            if !errorlevel!==0 (
                for /f "tokens=2 delims=:" %%b in ("!line!") do (
                    set "ipraw=%%b"
                    REM Remove leading spaces
                    for /f "tokens=* delims= " %%c in ("!ipraw!") do set "ipclean=%%c"
                    REM Remove (Preferred)
                    set "ipclean=!ipclean:(Preferred)=!"
                    set "ipclean=!ipclean: =!"
                    set TEMP_IPV4=!ipclean!
                    set HAS_IPV4=1
                )
            )
        )
        
        REM Get Subnet Mask
        echo !line! | findstr /C:"Subnet Mask" >nul
        if !errorlevel!==0 (
            for /f "tokens=2 delims=:" %%b in ("!line!") do (
                set "maskraw=%%b"
                for /f "tokens=* delims= " %%c in ("!maskraw!") do set "maskclean=%%c"
                set TEMP_MASK=!maskclean!
            )
        )
        
        REM Detect Default Gateway label
        echo !line! | findstr /C:"Default Gateway" >nul
        if !errorlevel!==0 (
            set WAITING_GW=1
            REM Try to get gateway on same line first
            for /f "tokens=2* delims=:" %%b in ("!line!") do (
                set "gwraw=%%b"
                for /f "tokens=* delims= " %%c in ("!gwraw!") do set "gwtest=%%c"
                REM Check if it's not empty and is IPv4
                if not "!gwtest!"=="" (
                    set "firstchar=!gwtest:~0,1!"
                    if "!firstchar!" geq "0" if "!firstchar!" leq "9" (
                        set TEMP_GW=!gwtest!
                        set WAITING_GW=0
                    )
                )
            )
        )
        
        REM Capture Default Gateway value from next line if waiting
        if !WAITING_GW!==1 (
            set "gwcandidate=!line!"
            for /f "tokens=* delims= " %%g in ("!gwcandidate!") do set "gwclean=%%g"
            if not "!gwclean!"=="" (
                set "firstchar=!gwclean:~0,1!"
                if "!firstchar!" geq "0" if "!firstchar!" leq "9" (
                    set TEMP_GW=!gwclean!
                    set WAITING_GW=0
                )
            )
        )
    )
)

REM Print last adapter if it has IPv4
if !HAS_IPV4!==1 (
    echo Adapter: !TEMP_ADAPTER!
    echo   IPv4: !TEMP_IPV4!
    if not "!TEMP_MASK!"=="" echo   Subnet Mask: !TEMP_MASK!
    if not "!TEMP_GW!"=="" echo   Default Gateway: !TEMP_GW!
    echo.
    set ADAPTER_FOUND=1
)

del "%TEMP%\ipconfig_temp.txt" 2>nul

if !ADAPTER_FOUND!==0 (
    echo No physical Ethernet or Wireless adapters with IPv4 found.
    echo.
)

echo ====================================================================
echo                    REPORT COMPLETED
echo ====================================================================
echo.
echo Press any key to exit...
pause >nul

endlocal
