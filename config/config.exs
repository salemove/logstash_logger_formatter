use Mix.Config

config :logger, :logstash_formatter, extra_fields: %{application: :logstash_formatter}
