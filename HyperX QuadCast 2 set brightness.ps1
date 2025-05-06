# known "major" (not "secondary") HID IDs of HyperX QuadCast 2
$deviceMajorIds = @(
    "HID\VID_03F0&PID_09AF&MI_00"
)


### Utils

function Fail([string] $errorMessage)
{
    Write-Host "Error: $errorMessage" -ForegroundColor Red
    Write-Host "Brightness not changed" -ForegroundColor Yellow
    Exit 1
}

$brightnessPercent = $args[0]
if (($brightnessPercent -lt 0) -or ($brightnessPercent -gt 100))
{ 
    Fail "Brightness must be in range [0; 100].`r`nExample (set brightness to 10%):`r`n& ""<path>\script.ps1"" 10"
}

### Search for the device

# C# code that lists available devices
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
using Microsoft.Win32.SafeHandles;

public static class WinAPI
{
    private const int DIGCF_PRESENT = 2;
    private const int DIGCF_DEVICEINTERFACE = 16;

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SP_DEVICE_INTERFACE_DATA
    {
        public int cbSize;
        public Guid InterfaceClassGuid;
        public int Flags;
        public IntPtr Reserved;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SP_DEVICE_INTERFACE_DETAIL_DATA
    {
        public int cbSize;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 512)]
        public byte[] DevicePath;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct SP_DEVINFO_DATA
    {
        public int cbSize;
        public Guid ClassGuid;
        public int DevInst;
        public IntPtr Reserved;
    }

    [DllImport("Kernel32", CharSet = CharSet.Unicode)]
    public static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);
    [DllImport("hid.dll")]
    public static extern void HidD_GetHidGuid(out Guid gHid);
    [DllImport("hid.dll")]
    public static extern bool HidD_SetFeature(SafeFileHandle hidDeviceObject, byte[] lpReportBuffer, int reportBufferLength);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SetupDiGetClassDevs(ref Guid ClassGuid, string Enumerator, IntPtr hwndParent, int Flags);
    [DllImport("setupapi.dll")]
    public static extern bool SetupDiEnumDeviceInfo(IntPtr DeviceInfoSet, uint MemberIndex, ref SP_DEVINFO_DATA DeviceInfoData);
    [DllImport("setupapi.dll")]
    public static extern bool SetupDiEnumDeviceInterfaces(IntPtr DeviceInfoSet, uint DeviceInfoData, ref Guid InterfaceClassGuid, uint MemberIndex, out SP_DEVICE_INTERFACE_DATA DeviceInterfaceData);
    [DllImport("setupapi.dll")]
    public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr DeviceInfoSet, ref SP_DEVICE_INTERFACE_DATA DeviceInterfaceData, IntPtr DeviceInterfaceDetailData, uint DeviceInterfaceDetailDataSize, out uint RequiredSize, IntPtr DeviceInfoData);
    [DllImport("setupapi.dll")]
    public static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr DeviceInfoSet, ref SP_DEVICE_INTERFACE_DATA DeviceInterfaceData, ref SP_DEVICE_INTERFACE_DETAIL_DATA DeviceInterfaceDetailData, uint DeviceInterfaceDetailDataSize, out uint RequiredSize, IntPtr DeviceInfoData);
    [DllImport("setupapi.dll")]
    public static extern bool SetupDiDestroyDeviceInfoList(IntPtr DeviceInfoSet);

    public static List<string> GetDevices()
    {
        List<string> devices = new List<string>();

        Guid hidGuid = Guid.Empty;
        HidD_GetHidGuid(out hidGuid);
        IntPtr hDevInfo = SetupDiGetClassDevs(ref hidGuid, null, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);

        try
        {
            SP_DEVINFO_DATA deviceInfoData = new SP_DEVINFO_DATA();
            deviceInfoData.cbSize = Marshal.SizeOf<SP_DEVINFO_DATA>(deviceInfoData);
            for (uint i = 0; SetupDiEnumDeviceInfo(hDevInfo, i, ref deviceInfoData); i++)
            {
                SP_DEVICE_INTERFACE_DATA interfaceData = new SP_DEVICE_INTERFACE_DATA();
                interfaceData.cbSize = Marshal.SizeOf(interfaceData);
                if (!SetupDiEnumDeviceInterfaces(hDevInfo, 0, ref hidGuid, i, out interfaceData))
                    continue;

                uint requiredSize = 0;
                SetupDiGetDeviceInterfaceDetail(hDevInfo, ref interfaceData, IntPtr.Zero, 0, out requiredSize, IntPtr.Zero);

                SP_DEVICE_INTERFACE_DETAIL_DATA detailData = new SP_DEVICE_INTERFACE_DETAIL_DATA();
                detailData.cbSize = IntPtr.Size == 8 ? 8 : 4 + Marshal.SystemDefaultCharSize; // x64/x86
                if (SetupDiGetDeviceInterfaceDetail(hDevInfo, ref interfaceData, ref detailData, requiredSize, out requiredSize, IntPtr.Zero))
                {
                    string devicePath = Encoding.UTF8.GetString(detailData.DevicePath).TrimEnd('\0');
                    devices.Add(devicePath);
                }
            }
        }
        finally
        {
            SetupDiDestroyDeviceInfoList(hDevInfo);
        }

        return devices;
    }
}
"@

Write-Host "`r`nSearching for devices..."
[regex]$deviceIdsPattern = [regex]::new(($deviceMajorIds | ForEach-Object { [regex]::Escape($_.Replace("\", "#")) }) -join "|", [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)
[array]$devices = [WinAPI]::GetDevices() | Where-Object { $_ -match $deviceIdsPattern }

if ($devices.Count -eq 0) { Fail "The device is not connected or not accessible" }
if ($devices.Count -ne 1) { Fail "Too many devices found: $($devices.Count)`r`n$($devices | Out-String)`r`nDisconnect them all and connect the only one." }
$devicePath = $devices[0]
Write-Host "Device found: $devicePath"

### Connect to the device

function Connect([string] $devicePath)
{
    Write-Host "`r`nConnecting to '$devicePath'..."
    [Microsoft.Win32.SafeHandles.SafeFileHandle]$safeFileHandle = [WinAPI]::CreateFile($devicePath, 3221225472, 3, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
    if ($safeFileHandle.IsInvalid)
    {
        $safeFileHandle.Dispose()
        Fail "Could not connect to the device"
    }
    Write-Host "Connected to the device`r`n"
    return $safeFileHandle
}
$hidDeviceObj = Connect $devicePath

### Set brightness

function SetFeature([Microsoft.Win32.SafeHandles.SafeFileHandle] $hidDeviceObject, [byte[]] $buffer)
{
    if ([WinAPI]::HidD_SetFeature($hidDeviceObj, $buffer, $buffer.Length) -eq $false)
    {
        Fail "SetFeature error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
}

Write-Host "Changing brightness..."
$featureBufferLength = 65;

# Step 1. Brightness setting
$buffer = [byte[]]::new($featureBufferLength)
$buffer[13] = [byte]($brightnessPercent * 255.0 / 100.0)
SetFeature $hidDeviceObj $buffer

# Step 2. Save changes
$buffer = [byte[]]::new($featureBufferLength)
$buffer[1] = 4
$buffer[2] = 253
SetFeature $hidDeviceObj $buffer

Write-Host "Brightness changed to $brightnessPercent% successfully`r`n" -ForegroundColor Green
