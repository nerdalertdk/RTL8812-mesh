// SPDX-License-Identifier: GPL-2.0-only
/* One-shot test helper for rtw_usb control-transfer -EPROTO retry. */

#include <linux/atomic.h>
#include <linux/kprobes.h>
#include <linux/module.h>
#include <linux/ptrace.h>
#include <linux/usb.h>

#define RTW_USB_VENDOR_ID_REALTEK	0x0bda
#define RTW_USB_PRODUCT_ID_8812AU	0x8812
#define RTW_USB_CMD_REQ			0x05

struct control_probe_data {
	bool target;
};

static ushort target_addr = 0x5a7;
module_param(target_addr, ushort, 0444);
MODULE_PARM_DESC(target_addr, "RTL8812AU register address to target");

static atomic_t inject_remaining = ATOMIC_INIT(1);
static atomic_t matching_calls = ATOMIC_INIT(0);

static int control_entry(struct kretprobe_instance *instance,
			 struct pt_regs *regs)
{
	struct control_probe_data *data =
		(struct control_probe_data *)instance->data;
	struct usb_device *udev;
	unsigned long request;
	unsigned long value;

	udev = (struct usb_device *)regs_get_kernel_argument(regs, 0);
	request = regs_get_kernel_argument(regs, 2);
	value = regs_get_kernel_argument(regs, 4);

	data->target = udev &&
		le16_to_cpu(udev->descriptor.idVendor) ==
			RTW_USB_VENDOR_ID_REALTEK &&
		le16_to_cpu(udev->descriptor.idProduct) ==
			RTW_USB_PRODUCT_ID_8812AU &&
		request == RTW_USB_CMD_REQ && value == target_addr;
	if (data->target)
		atomic_inc(&matching_calls);

	return 0;
}

static int control_return(struct kretprobe_instance *instance,
			  struct pt_regs *regs)
{
	struct control_probe_data *data =
		(struct control_probe_data *)instance->data;

	if (data->target && regs_return_value(regs) >= 0 &&
	    atomic_cmpxchg(&inject_remaining, 1, 0) == 1)
		regs_set_return_value(regs, -EPROTO);

	return 0;
}

static struct kretprobe control_probe = {
	.kp.symbol_name = "usb_control_msg",
	.entry_handler = control_entry,
	.handler = control_return,
	.data_size = sizeof(struct control_probe_data),
	.maxactive = 8,
};

static int __init usb_ctrl_eproto_injector_init(void)
{
	int ret;

	ret = register_kretprobe(&control_probe);
	if (ret)
		return ret;

	pr_info("rtw_usb: armed control -EPROTO injection for register 0x%x\n",
		target_addr);
	return 0;
}

static void __exit usb_ctrl_eproto_injector_exit(void)
{
	unregister_kretprobe(&control_probe);
	pr_info("rtw_usb: control injector removed, remaining=%d matching_calls=%d missed=%d\n",
		atomic_read(&inject_remaining), atomic_read(&matching_calls),
		control_probe.nmissed);
}

module_init(usb_ctrl_eproto_injector_init);
module_exit(usb_ctrl_eproto_injector_exit);

MODULE_DESCRIPTION("One-shot kretprobe injector for rtw_usb control -EPROTO testing");
MODULE_LICENSE("GPL");
