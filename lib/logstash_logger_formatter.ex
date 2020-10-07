defmodule LogstashLoggerFormatter do
  @moduledoc """
  This is a replacement for Logger console backend default formatter.

  It allows formatting log records in Logstash-friendly format and continue
  using Logger console backend, which is robust and doesn't bring the system
  down if for some reason I/O subsystem becomes too slow or even got stuck.

  See [Logger documentation](https://hexdocs.pm/logger/Logger.html#module-custom-formatting).

  The formatter is configured via `:logstash_formatter` key in `config.exs`:

      config :logger, :logstash_formatter,
        engine: Poison,
        timestamp_field: "@timestamp",
        message_field: "message",
        extra_fields: %{"application" => "foo"}

      config :logger, :console,
        format: {LogstashLoggerFormatter, :format}
  """

  @config Application.get_env(:logger, :logstash_formatter, [])
  @engine Keyword.get(@config, :engine, Poison)
  @ts_field Keyword.get(@config, :timestamp_field, "@timestamp")
  @msg_field Keyword.get(@config, :message_field, "message")
  @extra_fields Keyword.get(@config, :extra_fields, %{})

  @ts_formatter Logger.Formatter

  @spec format(Logger.level(), Logger.message(), Logger.Formatter.time(), Keyword.t()) ::
          IO.chardata()
  def format(level, message, timestamp, metadata) do
    event =
      metadata
      |> prepare_metadata()
      |> add_extra_fields()
      |> add_timestamp(timestamp)
      |> add_level(level)
      |> add_message(message)
      |> @engine.encode!(iodata: true)

    [event, '\n']
  end

  defp prepare_metadata(metadata) do
    metadata
    |> prepare_mfa()
    |> Map.new(fn {k, v} -> {metadata_key(k), format_metadata(v)} end)
  end

  defp prepare_mfa(metadata) do
    # Elixir versions prior to 1.10-otp-22 include `module` and `function/arity` in metadata.
    # Since 1.10-otp22 metadata includes a `mfa` tuple.
    # Unify the output and ensure lists with varying types do not end up in
    # logstash as it is unable to parse them.
    case Keyword.get(metadata, :mfa) do
      {mod, fun, arity} ->
        metadata
        |> Keyword.delete(:mfa)
        |> Keyword.merge(module: mod, function: "#{fun}/#{arity}")

      _ ->
        metadata
    end
  end

  defp metadata_key(:application), do: :otp_application
  defp metadata_key(key), do: key

  defp format_metadata(md)
       when is_pid(md)
       when is_reference(md),
       do: inspect(md)

  # Normally, structs shouldn't be passed to metadata, but if they're passed, we'll let
  # Poison/Jason handle encoding of structs
  defp format_metadata(%_{} = md) do
    md
  end

  defp format_metadata(md) when is_map(md) do
    Enum.into(md, %{}, fn {k, v} -> {k, format_metadata(v)} end)
  end

  defp format_metadata(md) when is_list(md) do
    Enum.map(md, &format_metadata/1)
  end

  defp format_metadata(md) when is_tuple(md) do
    md
    |> Tuple.to_list()
    |> format_metadata()
  end

  defp format_metadata(other), do: other

  defp add_extra_fields(event) do
    Enum.into(@extra_fields, event)
  end

  defp add_timestamp(event, timestamp) do
    Map.put(event, @ts_field, format_timestamp(timestamp))
  end

  defp format_timestamp({date, time}) do
    to_string([@ts_formatter.format_date(date), 'T', @ts_formatter.format_time(time), '+00:00'])
  end

  defp add_level(event, level) do
    Map.put(event, "level", Atom.to_string(level))
  end

  defp add_message(event, message) do
    Map.put(event, @msg_field, to_string(message))
  end
end
