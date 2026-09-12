/*
 * MagicKeyFix v2 - A1644 HID lower-filter glue.
 * The bus interception/report framing was cross-checked against the
 * MIT-licensed WinAppleKey project by George Samartzidis.
 * See ..\THIRD_PARTY_NOTICES.txt.
 */

#include "Driver.h"

static ULONG MkfLowerDeviceType(_In_ PDEVICE_OBJECT Pdo)
{
    PDEVICE_OBJECT lower = IoGetAttachedDeviceReference(Pdo);
    ULONG type;

    if (!lower) {
        return FILE_DEVICE_UNKNOWN;
    }

    type = lower->DeviceType;
    ObDereferenceObject(lower);
    return type;
}

static NTSTATUS MkfComplete(
    _In_ PIRP Irp,
    _In_ NTSTATUS Status,
    _In_ ULONG_PTR Information
)
{
    Irp->IoStatus.Status = Status;
    Irp->IoStatus.Information = Information;
    IoCompleteRequest(Irp, IO_NO_INCREMENT);
    return Status;
}

static NTSTATUS MkfStartCompletion(
    _In_ PDEVICE_OBJECT DeviceObject,
    _In_ PIRP Irp,
    _In_opt_ PVOID Context
)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)Context;

    UNREFERENCED_PARAMETER(DeviceObject);

    if (Irp->PendingReturned) {
        IoMarkIrpPending(Irp);
    }

    if (ext && ext->Lower &&
        (ext->Lower->Characteristics & FILE_REMOVABLE_MEDIA)) {
        ext->Self->Characteristics |= FILE_REMOVABLE_MEDIA;
    }

    if (ext) {
        IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    }

    return STATUS_SUCCESS;
}

static NTSTATUS MkfUsageCompletion(
    _In_ PDEVICE_OBJECT DeviceObject,
    _In_ PIRP Irp,
    _In_opt_ PVOID Context
)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)Context;

    UNREFERENCED_PARAMETER(DeviceObject);

    if (Irp->PendingReturned) {
        IoMarkIrpPending(Irp);
    }

    if (ext && ext->Lower && !(ext->Lower->Flags & DO_POWER_PAGABLE)) {
        ext->Self->Flags &= ~DO_POWER_PAGABLE;
    }

    if (ext) {
        IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    }

    return STATUS_SUCCESS;
}

#ifdef ALLOC_PRAGMA
#pragma alloc_text(INIT, DriverEntry)
#pragma alloc_text(PAGE, MkfAddDevice)
#pragma alloc_text(PAGE, MkfUnload)
#endif

NTSTATUS DriverEntry(
    _In_ PDRIVER_OBJECT DriverObject,
    _In_ PUNICODE_STRING RegistryPath
)
{
    ULONG i;

    UNREFERENCED_PARAMETER(RegistryPath);

    DriverObject->DriverExtension->AddDevice = MkfAddDevice;
    DriverObject->DriverUnload = MkfUnload;

    for (i = 0; i <= IRP_MJ_MAXIMUM_FUNCTION; ++i) {
        DriverObject->MajorFunction[i] = MkfDispatchPass;
    }

    DriverObject->MajorFunction[IRP_MJ_PNP] = MkfDispatchPnp;
    DriverObject->MajorFunction[IRP_MJ_POWER] = MkfDispatchPower;
    DriverObject->MajorFunction[IRP_MJ_INTERNAL_DEVICE_CONTROL] = MkfDispatchInternal;

    return STATUS_SUCCESS;
}

NTSTATUS MkfAddDevice(
    _In_ PDRIVER_OBJECT DriverObject,
    _In_ PDEVICE_OBJECT PhysicalDeviceObject
)
{
    PDEVICE_OBJECT filter = NULL;
    PDEVICE_OBJECT lower = NULL;
    PDEVICE_EXTENSION ext;
    NTSTATUS status;
    ULONG type;

    PAGED_CODE();

    type = MkfLowerDeviceType(PhysicalDeviceObject);

    status = IoCreateDevice(
        DriverObject,
        sizeof(DEVICE_EXTENSION),
        NULL,
        type,
        0,
        FALSE,
        &filter
    );

    if (!NT_SUCCESS(status)) {
        return status;
    }

    ext = (PDEVICE_EXTENSION)filter->DeviceExtension;
    RtlZeroMemory(ext, sizeof(*ext));
    ext->Self = filter;
    ext->Pdo = PhysicalDeviceObject;
    IoInitializeRemoveLock(&ext->RemoveLock, MKF_TAG, 0, 0);

    lower = IoAttachDeviceToDeviceStack(filter, PhysicalDeviceObject);
    if (!lower) {
        IoDeleteDevice(filter);
        return STATUS_DEVICE_REMOVED;
    }

    ext->Lower = lower;

    filter->Flags |= lower->Flags & (DO_DIRECT_IO | DO_BUFFERED_IO | DO_POWER_PAGABLE);
    filter->Flags &= ~DO_DEVICE_INITIALIZING;

    return STATUS_SUCCESS;
}

VOID MkfUnload(_In_ PDRIVER_OBJECT DriverObject)
{
    UNREFERENCED_PARAMETER(DriverObject);
    PAGED_CODE();
}

NTSTATUS MkfDispatchPass(_In_ PDEVICE_OBJECT DeviceObject, _In_ PIRP Irp)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;
    NTSTATUS status;

    if (!ext || !ext->Lower) {
        return MkfComplete(Irp, STATUS_DEVICE_REMOVED, 0);
    }

    status = IoAcquireRemoveLock(&ext->RemoveLock, Irp);
    if (!NT_SUCCESS(status)) {
        return MkfComplete(Irp, status, 0);
    }

    IoSkipCurrentIrpStackLocation(Irp);
    status = IoCallDriver(ext->Lower, Irp);
    IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    return status;
}

NTSTATUS MkfDispatchPower(_In_ PDEVICE_OBJECT DeviceObject, _In_ PIRP Irp)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;
    NTSTATUS status;

    if (!ext || !ext->Lower) {
        return MkfComplete(Irp, STATUS_DEVICE_REMOVED, 0);
    }

    status = IoAcquireRemoveLock(&ext->RemoveLock, Irp);
    if (!NT_SUCCESS(status)) {
        return MkfComplete(Irp, status, 0);
    }

    PoStartNextPowerIrp(Irp);
    IoSkipCurrentIrpStackLocation(Irp);
    status = PoCallDriver(ext->Lower, Irp);
    IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    return status;
}

NTSTATUS MkfDispatchPnp(_In_ PDEVICE_OBJECT DeviceObject, _In_ PIRP Irp)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;
    PIO_STACK_LOCATION stack;
    NTSTATUS status;
    UCHAR minor;

    if (!ext || !ext->Lower) {
        return MkfComplete(Irp, STATUS_DEVICE_REMOVED, 0);
    }

    stack = IoGetCurrentIrpStackLocation(Irp);
    minor = stack->MinorFunction;

    status = IoAcquireRemoveLock(&ext->RemoveLock, Irp);
    if (!NT_SUCCESS(status)) {
        return MkfComplete(Irp, status, 0);
    }

    if (minor == IRP_MN_REMOVE_DEVICE) {
        IoSkipCurrentIrpStackLocation(Irp);
        status = IoCallDriver(ext->Lower, Irp);
        IoReleaseRemoveLockAndWait(&ext->RemoveLock, Irp);
        IoDetachDevice(ext->Lower);
        IoDeleteDevice(DeviceObject);
        return status;
    }

    if (minor == IRP_MN_START_DEVICE) {
        IoCopyCurrentIrpStackLocationToNext(Irp);
        IoSetCompletionRoutine(Irp, MkfStartCompletion, ext, TRUE, TRUE, TRUE);
        return IoCallDriver(ext->Lower, Irp);
    }

    if (minor == IRP_MN_DEVICE_USAGE_NOTIFICATION) {
        if (!DeviceObject->AttachedDevice ||
            (DeviceObject->AttachedDevice->Flags & DO_POWER_PAGABLE)) {
            DeviceObject->Flags |= DO_POWER_PAGABLE;
        }

        IoCopyCurrentIrpStackLocationToNext(Irp);
        IoSetCompletionRoutine(Irp, MkfUsageCompletion, ext, TRUE, TRUE, TRUE);
        return IoCallDriver(ext->Lower, Irp);
    }

    IoSkipCurrentIrpStackLocation(Irp);
    status = IoCallDriver(ext->Lower, Irp);
    IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    return status;
}

NTSTATUS MkfInternalCompletion(
    _In_ PDEVICE_OBJECT DeviceObject,
    _In_ PIRP Irp,
    _In_opt_ PVOID Context
)
{
    PIO_STACK_LOCATION stack;
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)Context;
    ULONG code;

    UNREFERENCED_PARAMETER(DeviceObject);

    if (NT_SUCCESS(Irp->IoStatus.Status)) {
        stack = IoGetCurrentIrpStackLocation(Irp);
        code = stack->Parameters.DeviceIoControl.IoControlCode;

        if (code == IOCTL_INTERNAL_BTH_SUBMIT_BRB) {
            PBRB brb = (PBRB)stack->Parameters.Others.Argument1;

            if (brb && brb->BrbHeader.Type == BRB_L2CA_ACL_TRANSFER) {
                PUCHAR buffer = (PUCHAR)brb->BrbL2caAclTransfer.Buffer;
                ULONG size = brb->BrbL2caAclTransfer.BufferSize;

                // A1644 Bluetooth input packet: 2-byte BT/HID prefix + 9-byte keyboard report.
                if (buffer && size == 11) {
                    MagicKeyTransformA1644(buffer + 2, 9);
                }
            }
        }
        else if (code == IOCTL_INTERNAL_USB_SUBMIT_URB) {
            PURB urb = (PURB)stack->Parameters.Others.Argument1;

            if (urb && urb->UrbHeader.Function == URB_FUNCTION_BULK_OR_INTERRUPT_TRANSFER) {
                PUCHAR buffer = (PUCHAR)urb->UrbBulkOrInterruptTransfer.TransferBuffer;
                ULONG size = urb->UrbBulkOrInterruptTransfer.TransferBufferLength;

                // A1644 USB input packet: 1-byte report ID + 9-byte keyboard report.
                if (buffer && size == 10) {
                    MagicKeyTransformA1644(buffer + 1, 9);
                }
            }
        }
    }

    if (Irp->PendingReturned) {
        IoMarkIrpPending(Irp);
    }

    if (ext) {
        IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    }

    return Irp->IoStatus.Status;
}

NTSTATUS MkfDispatchInternal(_In_ PDEVICE_OBJECT DeviceObject, _In_ PIRP Irp)
{
    PDEVICE_EXTENSION ext = (PDEVICE_EXTENSION)DeviceObject->DeviceExtension;
    PIO_STACK_LOCATION stack;
    ULONG code;
    NTSTATUS status;
    BOOLEAN completionSet = FALSE;

    if (!ext || !ext->Lower) {
        return MkfComplete(Irp, STATUS_DEVICE_REMOVED, 0);
    }

    status = IoAcquireRemoveLock(&ext->RemoveLock, Irp);
    if (!NT_SUCCESS(status)) {
        return MkfComplete(Irp, status, 0);
    }

    stack = IoGetCurrentIrpStackLocation(Irp);
    code = stack->Parameters.DeviceIoControl.IoControlCode;

    if (code == IOCTL_INTERNAL_BTH_SUBMIT_BRB) {
        PBRB brb = (PBRB)stack->Parameters.Others.Argument1;

        if (brb && brb->BrbHeader.Type == BRB_L2CA_ACL_TRANSFER) {
            IoCopyCurrentIrpStackLocationToNext(Irp);
            IoSetCompletionRoutine(Irp, MkfInternalCompletion, ext, TRUE, TRUE, TRUE);
            completionSet = TRUE;
        }
        else {
            IoSkipCurrentIrpStackLocation(Irp);
        }
    }
    else if (code == IOCTL_INTERNAL_USB_SUBMIT_URB) {
        IoCopyCurrentIrpStackLocationToNext(Irp);
        IoSetCompletionRoutine(Irp, MkfInternalCompletion, ext, TRUE, TRUE, TRUE);
        completionSet = TRUE;
    }
    else {
        IoSkipCurrentIrpStackLocation(Irp);
    }

    status = IoCallDriver(ext->Lower, Irp);
    if (!completionSet) {
        IoReleaseRemoveLock(&ext->RemoveLock, Irp);
    }
    return status;
}
