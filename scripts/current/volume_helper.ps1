$script:QuietSavedVolumeFile = Join-Path $StateDir 'quiet_saved_volume.json'
$script:VolumeLogFile = Join-Path $LogDir 'volume_helper.log'

function Write-VolumeLog {
    param([string]$Message)

    $timestamp = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    Add-Content -Path $script:VolumeLogFile -Value "[$timestamp] $Message" -ErrorAction SilentlyContinue
}

function Write-VolumeBackendLog {
    param([string]$Message)

    if ($env:FANCONTROL_TEST_VOLUME_LOG) {
        Add-Content -Path $env:FANCONTROL_TEST_VOLUME_LOG -Value $Message -ErrorAction SilentlyContinue
    }
}

function Initialize-VolumeInterop {
    if ('FanControl.Audio.VolumeController' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace FanControl.Audio
{
    internal enum EDataFlow
    {
        eRender,
        eCapture,
        eAll,
        EDataFlow_enum_count
    }

    internal enum ERole
    {
        eConsole,
        eMultimedia,
        eCommunications,
        ERole_enum_count
    }

    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class MMDeviceEnumeratorComObject
    {
    }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(EDataFlow dataFlow, int dwStateMask, out object ppDevices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        int GetDevice(string pwstrId, out IMMDevice ppDevice);
        int RegisterEndpointNotificationCallback(IntPtr pClient);
        int UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IMMDevice
    {
        int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, out IAudioEndpointVolume ppInterface);
        int OpenPropertyStore(int stgmAccess, out object ppProperties);
        int GetId(out string ppstrId);
        int GetState(out int pdwState);
    }

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IAudioEndpointVolume
    {
        int RegisterControlChangeNotify(IntPtr pNotify);
        int UnregisterControlChangeNotify(IntPtr pNotify);
        int GetChannelCount(out uint pnChannelCount);
        int SetMasterVolumeLevel(float fLevelDB, ref Guid pguidEventContext);
        int SetMasterVolumeLevelScalar(float fLevel, ref Guid pguidEventContext);
        int GetMasterVolumeLevel(out float pfLevelDB);
        int GetMasterVolumeLevelScalar(out float pfLevel);
        int SetChannelVolumeLevel(uint nChannel, float fLevelDB, ref Guid pguidEventContext);
        int SetChannelVolumeLevelScalar(uint nChannel, float fLevel, ref Guid pguidEventContext);
        int GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
        int GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
        int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, ref Guid pguidEventContext);
        int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
        int GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
        int VolumeStepUp(ref Guid pguidEventContext);
        int VolumeStepDown(ref Guid pguidEventContext);
        int QueryHardwareSupport(out uint pdwHardwareSupportMask);
        int GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
    }

    public static class VolumeController
    {
        private const int CLSCTX_ALL = 23;

        public static float GetMasterVolumeScalar()
        {
            IAudioEndpointVolume endpointVolume = GetEndpointVolume();
            float level;
            Marshal.ThrowExceptionForHR(endpointVolume.GetMasterVolumeLevelScalar(out level));
            return level;
        }

        public static void SetMasterVolumeScalar(float level)
        {
            if (level < 0f)
            {
                level = 0f;
            }

            if (level > 1f)
            {
                level = 1f;
            }

            IAudioEndpointVolume endpointVolume = GetEndpointVolume();
            Guid eventContext = Guid.Empty;
            Marshal.ThrowExceptionForHR(endpointVolume.SetMasterVolumeLevelScalar(level, ref eventContext));
        }

        private static IAudioEndpointVolume GetEndpointVolume()
        {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)new MMDeviceEnumeratorComObject();
            IMMDevice device;
            Marshal.ThrowExceptionForHR(enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device));

            Guid iid = typeof(IAudioEndpointVolume).GUID;
            IAudioEndpointVolume endpointVolume;
            Marshal.ThrowExceptionForHR(device.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out endpointVolume));
            return endpointVolume;
        }
    }
}
"@
}

function Get-SystemVolumePercent {
    if ($env:FANCONTROL_TEST_VOLUME_FILE) {
        $value = [int](Get-Content -Path $env:FANCONTROL_TEST_VOLUME_FILE -Raw)
        Write-VolumeBackendLog -Message "GET|$value"
        return $value
    }

    Initialize-VolumeInterop
    $scalar = [FanControl.Audio.VolumeController]::GetMasterVolumeScalar()
    return [int][Math]::Round($scalar * 100)
}

function Set-SystemVolumePercent {
    param([int]$Volume)

    $clampedVolume = [Math]::Max(0, [Math]::Min(100, $Volume))

    if ($env:FANCONTROL_TEST_VOLUME_FILE) {
        Set-Content -Path $env:FANCONTROL_TEST_VOLUME_FILE -Value ([string]$clampedVolume) -Encoding ASCII
        Write-VolumeBackendLog -Message "SET|$clampedVolume"
        return
    }

    Initialize-VolumeInterop
    [FanControl.Audio.VolumeController]::SetMasterVolumeScalar($clampedVolume / 100.0)
}

function Get-SavedQuietVolume {
    if (-not (Test-Path $script:QuietSavedVolumeFile)) {
        return $null
    }

    try {
        return Get-Content -Path $script:QuietSavedVolumeFile -Raw | ConvertFrom-Json
    } catch {
        Write-VolumeLog "Invalid saved volume state found, deleting it"
        Remove-Item -Path $script:QuietSavedVolumeFile -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Save-QuietVolume {
    param([int]$Volume)

    @{
        Volume = $Volume
        SavedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    } | ConvertTo-Json | Set-Content -Path $script:QuietSavedVolumeFile -Encoding UTF8
}

function Enter-QuietVolumeMode {
    try {
        $savedVolume = Get-SavedQuietVolume
        if ($null -eq $savedVolume) {
            $currentVolume = Get-SystemVolumePercent
            Save-QuietVolume -Volume $currentVolume
            Write-VolumeLog "Saved current volume: $currentVolume"
        } else {
            Write-VolumeLog "Saved volume already exists: $($savedVolume.Volume)"
        }

        Set-SystemVolumePercent -Volume 0
        Write-VolumeLog 'Set system volume to 0 for Quiet mode'
    } catch {
        Write-VolumeLog "Failed to enter Quiet volume mode: $($_.Exception.Message)"
    }
}

function Restore-QuietVolumeIfNeeded {
    try {
        $savedVolume = Get-SavedQuietVolume
        if ($null -eq $savedVolume) {
            Write-VolumeLog 'No saved volume state to restore'
            return $false
        }

        $volumeToRestore = [int]$savedVolume.Volume
        Set-SystemVolumePercent -Volume $volumeToRestore
        Remove-Item -Path $script:QuietSavedVolumeFile -Force -ErrorAction SilentlyContinue
        Write-VolumeLog "Restored volume to: $volumeToRestore"
        return $true
    } catch {
        Write-VolumeLog "Failed to restore saved volume: $($_.Exception.Message)"
        return $false
    }
}
