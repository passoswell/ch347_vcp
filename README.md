# CH347 VCP kernel drivers

Linux kernel drivers for CH347 vendor-class protocols.

This project provides the means of building and installing four kernel modules:

- `mfd-ch347.ko` (base MFD driver)
- `i2c-ch347.ko`
- `gpio-ch347.ko`
- `spi-ch347.ko`

The I2C, GPIO, and SPI modules sit on top of the MFD driver and work in parallel.

CH347 UART interfaces are handled separately (in parallel to these drivers) by either the standard USB CDC driver or W-CH UART drivers.

JTAG can be handled in userspace via openFPGALoader (open source) or the binary OpenOCD driver released by W-CH.

Credits: This repository is forked from the original project by aystarik: https://github.com/aystarik/ch347_vcp

## Quick start

From the repository root:

```sh
make load
```

This builds the modules and loads them locally with `insmod` (no permanent installation).

To unload:

```sh
make unload
```

## Build, sign, load, and unload

Build modules:

```sh
make
```

This builds all modules and copies `*.ko` files to the repository root.

### Module signing

If signing keys exist at these default locations, modules are signed automatically during `make`:

- `~/signing_key.priv`
- `~/signing_key.x509`

To use custom key paths:

```sh
make SIGN_KEY=/path/to/signing_key.priv SIGN_CERT=/path/to/signing_key.x509
```

If Secure Boot is enabled and loading fails with key/signature errors, see:
https://unix.stackexchange.com/questions/751517/insmod-causes-key-rejected-by-service/751571#751571

### Load modules locally (non-persistent)

```sh
make load
```

This uses `insmod` on local `.ko` files and does not install modules into `/lib/modules`.

### Unload modules

```sh
make unload
```

Modules are unloaded in reverse dependency order.

### Optional permanent installation

```sh
sudo make modules_install
```

### Optional root mode (without sudo prefix)

```sh
make SUDO= load
make SUDO= unload
```

## udev rules

This repository includes [99-ch34_vcp_spidev.rules](99-ch34_vcp_spidev.rules) to improve non-root access and SPI device setup.

What the rule file does:

- Sets mode `0660` and group `i2c` for I2C adapters (`i2c-*`)
- Sets mode `0660` and group `gpio` for GPIO chips (`gpiochip*`)
- Detects CH347 in SPI mode (`idVendor=1a86`, `idProduct=55db`) and auto-binds `spi*.0` to `spidev`
- Sets mode `0660` and group `spi` for `spidev*` nodes

Install on Linux:

```sh
sudo cp 99-ch34_vcp_spidev.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

If needed, create groups and add your user:

```sh
sudo groupadd -f i2c
sudo groupadd -f gpio
sudo groupadd -f spi
sudo usermod -aG i2c,gpio,spi "$USER"
```

Log out and back in (or reboot) so the new group membership is applied.

## I2C (i2c-ch347.ko)

Acts as a standard I2C master controller. Standard tools such as i2c-tools work, and slave devices can be added using normal kernel interfaces.

## GPIO (gpio-ch347.ko)

Controls 8 GPIO pins. There is no safety check to prevent conflicts if a pin is also used by another protocol.

GPIO | PIN | UART0/1 | SPI | JTAG | I2C
-|-|-|-|-|-
0 | 6 | CTS0 | SCK | TCK |
1 | 7 | RTS0 | MISO | TDO |
2 | 5 | DSR0 | SCS0 | TMS |
3 | 11 | RI0 |  |  | SCL
4 | 15 | DCD0/ACT |  |  |
5 | 9 | TNOW0/DTR0 | SCS1 | TRST |
6 | 2 | CTS1 |  |  |
7 | 13 | RTS1 |  |  |

If Mode 1 of CH347 (VCP) is used, UART1, I2C and SPI are made available. If no hardware flow control is used with UART1, 5 of the 8 GPIOs can be used freely: IO2 (pin 5), IO4 (pin 15), IO5 (pin 9), IO6 (pin 2) and IO7 (pin 13).

## SPI (spi-ch347.ko)

Adds an SPI master controller with speeds up to 60 MHz and support for two slave chip-select lines.

If your wiring/setup is signal-limited (for example, dupont wires), lower the configured SPI clock.

> Warning: In this implementation, the SPI kernel module does not manage chip-select (CS). CS must be controlled by user-space code. This allows flexible CS pin selection, but can increase SPI transaction latency.

To add a slave device, write a string with:

- driver name
- SPI mode
- bits per word
- chip-select number
- optional frequency

Example:

```sh
echo "spi-nor 9 0 0 15000" > /sys/class/.../spi2/new_device
```

To use the device from userspace, bind `spidev`:

```sh
echo "spidev" > /sys/class/spi_master/spi0/spi0.0/driver_override
echo "spi0.0" > /sys/bus/spi/drivers/spidev/bind
```

Verify device creation:

```sh
file /dev/spidev0.0
```

Expected output:

```text
/dev/spidev0.0: character special (153/0)
```
