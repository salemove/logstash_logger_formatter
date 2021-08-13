defmodule LogstashLoggerFormatter do
  @moduledoc """
  This is a replacement for Logger console backend default formatter.

  It allows formatting log records in Logstash-friendly format and continue
  using Logger console backend, which is robust and doesn't bring the system
  down if for some reason I/O subsystem becomes too slow or even got stuck.

  See [Logger documentation](https://hexdocs.pm/logger/Logger.html#module-custom-formatting).

  The formatter is configured via `:logstash_formatter` key in `config.exs`:

      config :logger, :logstash_formatter,
        engine: Jason,
        timestamp_field: "@timestamp",
        message_field: "message",
        extra_fields: %{"application" => "foo"}

      config :logger, :console,
        format: {LogstashLoggerFormatter, :format}
  """

  @config Application.get_env(:logger, :logstash_formatter, [])
  @engine Keyword.get(@config, :engine, Jason)
  @ts_field Keyword.get(@config, :timestamp_field, "@timestamp")
  @msg_field Keyword.get(@config, :message_field, "message")
  @extra_fields Keyword.get(@config, :extra_fields, %{})
  @max_metadata_size Keyword.get(@config, :max_metadata_size, 10000)
  @max_metadata_item_size Keyword.get(@config, :max_metadata_item_size, 4000)

  @ts_formatter Logger.Formatter

  @encode_fn if function_exported?(@engine, :encode_to_iodata!, 1),
               do: :encode_to_iodata!,
               else: :encode!

  @spec format(Logger.level(), Logger.message(), Logger.Formatter.time(), Keyword.t()) ::
          IO.chardata()
  def format(level, message, timestamp, metadata) do
    event =
      metadata
      |> prepare_metadata()
      |> truncate_metadata()
      |> add_extra_fields()
      |> add_timestamp(timestamp)
      |> add_level(level)
      |> add_message(message)

    event = apply(@engine, @encode_fn, [event])

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

  defp truncate_metadata(md) do
    if metadata_too_big?(md) do
      Enum.reduce(md, %{}, fn {key, value}, acc ->
        Map.put(acc, key, maybe_truncate_item(value))
      end)
    else
      md
    end
  end

  defp maybe_truncate_item(md) when is_number(md) or is_atom(md) or is_struct(md), do: md
  defp maybe_truncate_item(item) do
    if metadata_item_too_big?(item), do: truncate_item(item), else: item
  end

  defp truncate_item(item) when is_list(item) do
    list_length = Kernel.length(item)
    keep_items_count = items_to_keep(metadata_byte_size(item), list_length)

    truncated_list =
      item
      |> Enum.take(keep_items_count)
      |> Enum.map(&maybe_truncate_item/1)

    if keep_items_count < list_length do
      if is_map(List.first(truncated_list)) do
        truncated_list ++ [%{"-pruned-" => true}]
      else
        truncated_list ++ ["-pruned-"]
      end
    else
      truncated_list
    end
  end

  defp truncate_item(item) when is_map(item) do
    items_in_map = Kernel.length(Map.keys(item))
    keep_items_count = items_to_keep(metadata_byte_size(item), items_in_map)

    item_subset = Map.take(item, Enum.take(Map.keys(item), keep_items_count))
    truncated_map = Enum.reduce(item_subset, %{}, fn {key, value}, acc ->
      Map.put(acc, key, maybe_truncate_item(value))
    end)
    if keep_items_count < items_in_map, do: Map.put(truncated_map, "-pruned-", true), else: truncated_map
  end

  defp truncate_item(item) do
    String.slice(apply(@engine, @encode_fn, [item]), 0..@max_metadata_item_size - 1) <> " (-pruned-)"
  end

  defp items_to_keep(byte_size, length) do
    max(floor((@max_metadata_item_size / byte_size) * length), 1)
  end

  defp metadata_item_too_big?(md), do: metadata_byte_size(md) > @max_metadata_item_size

  defp metadata_too_big?(md), do: metadata_byte_size(md) > @max_metadata_size

  defp metadata_byte_size(md), do: Kernel.byte_size(apply(@engine, @encode_fn, [md]))

  defp format_metadata(md)
       when is_pid(md)
       when is_reference(md),
       do: inspect(md)

  defp format_metadata(md) when is_function(md), do: inspect(md)

  # Normally, structs shouldn't be passed to metadata, but if they're passed, we'll let
  # Poison/Jason handle encoding of structs
  defp format_metadata(%_{} = md) do
    if struct_implemented?(md) do
      md
    else
      # If the Encoder cannot handle the struct we'll just convert it to a
      # regular map and log it.
      md
      |> Map.from_struct()
      |> Map.put("__struct__", md.__struct__)
      |> format_metadata()
    end
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

  defp struct_implemented?(data) do
    impl = @engine.Encoder.impl_for(data)
    impl && impl != @engine.Encoder.Any
  end
end
