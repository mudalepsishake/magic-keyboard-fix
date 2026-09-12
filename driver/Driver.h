#pragma once

#include <ntddk.h>
#include <wdm.h>
#include <bthdef.h>
#include <bthguid.h>
#include <bthioctl.h>
#include <bthddi.h>
#include <usbioctl.h>
#include <usbdi.h>

#define MKF_TAG 'FkMK'

typedef struct _DEVICE_EXTENSION {
    PDEVICE_OBJECT Self;
    PDEVICE_OBJECT Lower;
    PDEVICE_OBJECT Pdo;
    IO_REMOVE_LOCK RemoveLock;
} DEVICE_EXTENSION, *PDEVICE_EXTENSION;

DRIVER_INITIALIZE DriverEntry;
DRIVER_ADD_DEVICE MkfAddDevice;
DRIVER_UNLOAD MkfUnload;

_Dispatch_type_(IRP_MJ_PNP)
DRIVER_DISPATCH MkfDispatchPnp;

_Dispatch_type_(IRP_MJ_POWER)
DRIVER_DISPATCH MkfDispatchPower;

_Dispatch_type_(IRP_MJ_INTERNAL_DEVICE_CONTROL)
DRIVER_DISPATCH MkfDispatchInternal;

DRIVER_DISPATCH MkfDispatchPass;

NTSTATUS MkfInternalCompletion(
    _In_ PDEVICE_OBJECT DeviceObject,
    _In_ PIRP Irp,
    _In_opt_ PVOID Context
);

#ifdef __cplusplus
extern "C" {
#endif

void MagicKeyTransformA1644(unsigned char* report, unsigned long size);

#ifdef __cplusplus
}
#endif
