// SPDX-License-Identifier: GPL-2.0-only
/* One-shot test helper for rtw_usb RX -EPROTO recovery. */

#include <linux/atomic.h>
#include <linux/kprobes.h>
#include <linux/module.h>
#include <linux/ptrace.h>
#include <linux/usb.h>

static atomic_t inject_remaining = ATOMIC_INIT(1);

static int inject_eproto(struct kprobe *probe, struct pt_regs *regs)
{
	struct urb *urb;

	urb = (struct urb *)regs_get_kernel_argument(regs, 0);
	if (urb && urb->status == 0 &&
	    atomic_cmpxchg(&inject_remaining, 1, 0) == 1)
		urb->status = -EPROTO;

	return 0;
}

static struct kprobe rx_complete_probe = {
	.symbol_name = "rtw_usb_read_port_complete",
	.pre_handler = inject_eproto,
};

static int __init usb_eproto_injector_init(void)
{
	int ret;

	ret = register_kprobe(&rx_complete_probe);
	if (ret)
		return ret;

	pr_info("rtw_usb: armed one-shot RX -EPROTO injection\n");
	return 0;
}

static void __exit usb_eproto_injector_exit(void)
{
	unregister_kprobe(&rx_complete_probe);
	pr_info("rtw_usb: RX -EPROTO injector removed, remaining=%d\n",
		atomic_read(&inject_remaining));
}

module_init(usb_eproto_injector_init);
module_exit(usb_eproto_injector_exit);

MODULE_DESCRIPTION("One-shot kprobe injector for rtw_usb RX -EPROTO testing");
MODULE_LICENSE("GPL");
