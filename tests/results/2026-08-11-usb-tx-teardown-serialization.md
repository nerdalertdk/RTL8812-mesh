# RTL8812AU TX teardown serialization — 2026-08-11

## Result

The disposable kernel-side teardown test established the relevant Linux USB
lifecycle ordering. A TX completion scheduled `device_release_driver()` on
`system_unbound_wq`, then delayed for five seconds. The unbound worker started
immediately, and the USB interface left the driver within 100 ms. The driver's
`rtw_usb_deinit_tx()` markers did not execute until the completion returned
five seconds later.

The captured sequence was:

1. completion logged that it scheduled driver unbind;
2. unbound work logged that it requested unbind in the same second;
3. five seconds later, teardown logged
   `pending_urbs=0 active_callbacks=0` before and after
   `usb_kill_anchored_urbs()`;
4. the controlled USB reset occurred, and the interface rebound immediately.

This demonstrates that USB core serializes interface-driver removal behind an
in-progress completion callback. Consequently, a real USB disconnect cannot
enter `rtw_usb_deinit_tx()` while such a callback is active; attempting to
force that overlap is not valid driver evidence.

The controlled unbind/rebind completed within the configured 20-second bound,
with a zero post-kill anchor/callback state and no kernel safety signature.
The expected controlled reset is excluded from transport-fault classification.
Production DKMS 0.1.5 was restored and exact-provenance checked afterward.

## Scope

This is disposable test evidence only. It does not turn synthetic timing into a
physical USB fault result and does not replace the remaining physical
unplug/re-enumeration or USB-path qualification gates.
