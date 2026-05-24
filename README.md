# ch347_vcp
Linux kernel drivers for vendor class protocols of CH347

Set has four drivers -- base is MFD (mfd-ch347.ko), and on top of it are I2C, GPIO and SPI drivers (Modes 1 and 3).

CH347 can also do UART(s), which are handled independently (in parallel to _these_ drivers) by either standard USB CDC driver or
by common W-CH driver for all their UARTs.

JTAG support is handled in userspace via openFPGALoader (open source) or binary driver for OpenOCD released by W-CH.

## Build, sign, load and unload

From the repository root:

```sh
make
```

This builds all modules and copies `*.ko` files to the source directory. If signing keys are present at the default paths (`~/signing_key.priv` and `~/signing_key.x509`), modules are signed automatically.

If Secure Boot is enabled and module loading fails with key/signature errors, see this troubleshooting guide:
https://unix.stackexchange.com/questions/751517/insmod-causes-key-rejected-by-service/751571#751571

To use custom signing key paths:

```sh
make SIGN_KEY=/path/to/signing_key.priv SIGN_CERT=/path/to/signing_key.x509
```

To build and load modules without permanent installation into `/lib/modules`:

```sh
make load
```

To unload modules (in reverse dependency order):

```sh
make unload
```

If you run as root and do not want `sudo` in the Makefile commands:

```sh
make SUDO= load
make SUDO= unload
```

For permanent installation (optional):

```sh
sudo make modules_install
```

## udev rules

This repository includes [99-ch34_vcp_spidev.rules](99-ch34_vcp_spidev.rules), which helps non-root access and SPI setup after the device appears.

What it does:

- Sets `0660` permissions and group ownership for I2C adapters (`i2c-*`) to group `i2c`
- Sets `0660` permissions and group ownership for GPIO chips (`gpiochip*`) to group `gpio`
- Detects CH347 in SPI mode (USB `idVendor=1a86`, `idProduct=55db`) and auto-binds `spi*.0` to `spidev`
- Sets `0660` permissions and group ownership for `spidev*` nodes to group `spi`

Install on Linux:

```sh
sudo cp 99-ch34_vcp_spidev.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

If needed, create the groups and add your user:

```sh
sudo groupadd -f i2c
sudo groupadd -f gpio
sudo groupadd -f spi
sudo usermod -aG i2c,gpio,spi "$USER"
```

Log out and log back in (or reboot) so new group membership is applied.

## I2C (i2c-ch347.ko)
Driver behaves as an ordinary I2C master controller, e.g. _i2c-tools_ work with it and it
is possible to add slave devices via usual methods.

## GPIO (gpio-ch347.ko)
Driver controls 8 pins, there is no check if these pins are used by any other protocol.

GPIO | PIN | UART0/1 | SPI | JTAG | I2C
-|-|-|-|-|-
0 | 6 | CTS0 | SCK | TCK
1  | 7 | RTS0|MISO | TDO
2 | 5 | DSR0 | SCS0 | TMS
3 | 11 |  RI0 |||SCL
4 | 15 | DCD0/ACT |||
5 | 9 | TNOW0/DTR0|SCS1|TRST
6 |2| CTS1
7 | 13 |RTS1

## SPI (spi-ch347.ko)
Driver adds new SPI master controller with speeds up to 60MHz and 2 slaves. If your setup does not support such frequencies (think "dupont" wires),
decrease frequency when adding slave devices.

> Warning: In this implementation, the SPI kernel module does not manage the chip-select (CS) pin. CS must be controlled by user-space code. This allows you to choose which pin acts as CS, but SPI transactions can take longer due to user-space CS handling.

To add a slave device you should send string containing device driver name, SPI mode, bits per word, chip select number, and optionally frequency into "new_device" file in sysfs directory of the driver.
```
echo "spi-nor 9 0 0 15000" > /sys/class/.../spi2/new_device
```

To use the device from userspace, first bind `spidev` driver to the device.
```sh
echo "spidev" > /sys/class/spi_master/spi0/spi0.0/driver_override
echo "spi0.0" > /sys/bus/spi/drivers/spidev/bind
```

The device is then made available for us.
```sh
file /dev/spidev0.0
```
> `/dev/spidev0.0: character special (153/0)`
