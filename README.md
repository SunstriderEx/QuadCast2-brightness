# HyperX QuadCast 2 lighting brightness control

## The issue

HyperX NGENUITY app meant to be able to customize lighting to all supported devices including USB microphone HyperX QuadCast 2.

But there is a bug that blocks any lighting settings to be saved to this microphone:

![HyperX NGENUITY issue](/misc/HyperX%20NGENUITY%20screenshot.png)

Error shown by clicking at question mark

> **Can't Save Current effects**
>
> Some of these effects need NGENUITY and can't be saved directly to your device.
> Save the current lighting profile onto your microphone by removing these effects from your stack:  
> \- VU Meter Effect

Of course there is no such effect in the stack. And no Save button visible anywhere.

QuadCast 2 was released in summer 2024. Since that moment the problem was publicly reported many times, on reddit for i.e. Despite this it didn't fixed yet, and there is no feedback by software and hardware developers.

Default lighting so bright that it blinds and distracts with its animation, it might even light up the entire room. There is must be feature to turn lights off completely or to control brightness over the entire range. Otherwise the microphone is so uncomfortable and hard to use.

## Solution

To solve this issue the PowerShell script was written. It can change lighting brightness of QuadCast 2 from 0 to 100% and save a value to the microphone. Settings persist after powering off or connecting the microphone to another device.

## How to use

Run the script in PowerShell with number as argument that means percent of lighting brightness. Example how to set brightness to `5%`:

```PowerShell
& "C:\path\HyperX QuadCast 2 set brightness.ps1" 5
```

![Example use screenshot](/misc/Example%20use%20screenshot.png)

After a second the microphone will change its lighting.
