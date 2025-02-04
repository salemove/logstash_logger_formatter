# Changelog

## 1.1.5

* Add support for Elixir 1.14 with OTP 25

## 1.1.4

- Allow crash reports to be ingested by ElasticSearch
  * Omit `crash_reason` and `initial_call` to allow ingestion
  * Limit crash report message to 100 characters by default to reduce the
    possibility of logging out sensitive information. A separate error
    reporting tool should be used to get the full error message and stack
    trace. The message length limit is configurable via
    `crash_reports.message_length`.

## 1.1.3

- Fix crashes when using complex map keys in metadata. 
  The map key is formatted similarly to all other metadata, but as all resulting keys must be strings:
    * Should the formatting result be a list, join it with the "," separator.
    * Should it be anything more complex, replace the key with "unencodable map key".
  Previously, the formatter raised an error when it encountered such message.

## 1.1.2

- Allow message and metadata to be logged in cases where it contains invalid UTF-8
bytes. Previously, the formatter raised an error when it encountered such message.

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
