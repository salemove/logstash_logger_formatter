# Changelog

## 1.1.1

  * Avoid crashing when metadata is iosteam and not a string.

## 1.1.0

  * Add metadata truncation. By default all metadata bigger than 10000 bytes will be truncated.

## 1.0.1

  * Avoid crashing when metadata includes a function

## 1.0.0

  * Change default JSON encoder to Jason

## 0.5.0

  * Add support for Elixir 1.11 with OTP 23

## 0.4.0

  * Add support for Elixir 1.10 with OTP 22

## 0.3.0

  * Add support for Poison 4.x

## 0.2.0

  * Use JSON engine protocols to encode structs in metadata

## 0.1.2

  * Support Date/Time structs in metadata

## 0.1.1

  * Make Poison optional dependency, which will fix compilation warnings

## 0.1.0

  * Initial release
