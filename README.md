# LogstashLoggerFormatter

Logstash JSON formatter for Elixir standard Logger console backend.

## Installation

The package can be installed by adding `logstash_logger_formatter` to your 
list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logstash_logger_formatter, "~> 0.1.0"}
  ]
end
```

Documentation can be found at
[https://hexdocs.pm/logstash_logger_formatter](https://hexdocs.pm/logstash_logger_formatter).

## Usage

Add to your `config.exs`:

```elixir
config :logger, :console,
  format: {LogstashLoggerFormatter, :format}
```

## License

MIT License, Copyright (c) 2018 SaleMove
