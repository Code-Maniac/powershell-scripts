$cmakefile = "./CMakeLists.txt"
$cmakedir="../../../../cmake"

# check we are in an SDKC project
if(-not(Test-Path -Path $cmakefile -PathType Leaf)) {
    Write-Error "Not in SDKC project. Not CMakeLists.txt found"
    Exit 1
}

# Ensure build dir exists
New-Item -ItemType Directory -Force ./build/target

# go to the new directory
cd ./build/target

$cmakefile = "../../$cmakefile"
# get the architecture
$SEL = Select-String $cmakefile -Pattern "IMX28"
if($SEL -ne $null) {
    $toolchain_file="$cmakedir/cygwin_toolchain_imx28.cmake"
    cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE:STRING=$toolchain_file -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DUNITTESTS:BOOL=OFF -DCMAKE_CXX_COMPILER_ID=GNU -DCMAKE_C_COMPILER_ID=GNU -DCREATE_USB_PACKAGE=1 ../..
} else {
    $SEL = Select-String $cmakefile -Pattern "IMX6"
    if($SEL -ne $null) {
        $toolchain_file="$cmakedir/cygwin_toolchain_imx6.cmake"
        cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE:STRING=$toolchain_file -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DUNITTESTS:BOOL=OFF -DCMAKE_CXX_COMPILER_ID=GNU -DCMAKE_C_COMPILER_ID=GNU -DCREATE_USB_PACKAGE=1 ../..
    } else {
        $SEL = Select-String $cmakefile -Pattern "STM32"
        if($SEL -ne $null) {
            $toolchain_file="$cmakedir/cygwin_toolchain_Stm32.cmake"
            cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE:STRING=$toolchain_file -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DCREATE_USB_PACKAGE=1 ../..
        } else {
            Write-Error "No toolchain detected in CMakeLists.txt"
            Exit 1
        }
    }
}

# Write-Host $cmakeargs
# Exit 0
# cmake -G "Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE:STRING=$toolchain_file $cmakeargs ../..
cmake --build . --config Release --parallel $((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors)
cd ../..

$usbupdate = Get-ChildItem -Filter usbupdate/*.zip | Select-Object -First 1
if($usbupdate -eq $null) {
    Exit 0
}

$usb = gwmi win32_diskdrive | ?{$_.interfacetype -eq "USB"} | %{gwmi -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID=`"$($_.DeviceID.replace('\','\\'))`"} WHERE AssocClass = Win32_DiskDriveToDiskPartition"} |  %{gwmi -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID=`"$($_.DeviceID)`"} WHERE AssocClass = Win32_LogicalDiskToPartition"} | %{$_.deviceid}
if($usb -ne $null) {
    # extract to usb
    Copy-Item -Force -Path "usbupdate/$usbupdate" -Destination $usb/$usbupdate
    Expand-Archive -Force -Path $usb/$usbupdate -DestinationPath $usb
}