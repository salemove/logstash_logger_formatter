defmodule LogstashLoggerFormatterTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  require Logger

  @example_timestamp {{2023, 01, 01}, {12, 00, 00, 00}}
  @secret_value_example "my-secret-value"
  @phoenix_crash_example %{
    message: [
      "Process ",
      "#PID<0.2.0>",
      " terminating",
      [
        1,
        """
        ** (exit) {{{%SomeError{
        assigns: %{conn: %Plug.Conn{adapter: {Plug.Cowboy.Conn, :...}, assigns: %{layout: false, queues: []}, body_params: %{"foo": "#{@secret_value_example}"}, cookies: %Plug.Conn.Unfetched{aspect: :cookies}, halted: false, host: "localhost", method: "GET", owner: #PID<0.1369.0>, params: %{"foo" => "#{@secret_value_example}"}, path_info: ["my_path"], path_params: %{}, port: 4112, query_params: %{"foo" => "#{@secret_value_example}"}, remote_ip: {127, 0, 0, 1}, req_cookies: %Plug.Conn.Unfetched{aspect: :cookies, foo: "#{@secret_value_example}"}, req_headers: [{"accept", "*/*"}, {"authorization", "Bearer #{@secret_value_example}"}, {"host", "localhost:4112"}, {"user-agent", "curl/7.87.0"}], request_path: "/my_path", resp_body: nil, resp_cookies: %{}, resp_headers: [{"cache-control", "max-age=0, private, must-revalidate"}, {"access-control-allow-origin", "*"}, {"access-control-expose-headers", ""}, {"access-control-allow-credentials", "true"}], scheme: :http, script_name: [], secret_key_base: nil, state: :unset, status: 200}, queues: []}
        }}}, []}
        """,
        [
          "\n",
          "Initial Call: ",
          ":cowboy_stream_h.request_process/3",
          "\n",
          "Ancestors: ",
          "[#PID<0.2.0>, #PID<0.1.0>]"
        ],
        []
      ]
    ],
    metadata:
      Keyword.new(%{
        ancestors: ["#PID<0.2.0>", "#PID<0.1.0>"],
        crash_reason: ["some_reason", []],
        domain: [:otp, :sasl],
        erl_level: :error,
        error_logger: %{tag: :error_report, type: :crash_report},
        file: ~c"proc_lib.erl",
        function: "crash_report/4",
        gl: "#PID<0.2.0>",
        initial_call: {:cowboy_stream_h, :request_process, 3},
        line: 1,
        logger_formatter: %{title: "CRASH REPORT"},
        module: :proc_lib,
        pid: "#PID<0.2.0>",
        report_cb: "&:proc_lib.report_cb/2",
        time: 1_672_993_046_472_382,
        level: "error"
      })
  }

  setup do
    Logger.configure_backend(
      :console,
      format: {LogstashLoggerFormatter, :format},
      colors: [enabled: false],
      metadata: :all
    )
  end

  test "logs message in JSON format", %{test: test_name} do
    ref = make_ref()
    pid = self()

    message =
      capture_log(fn ->
        Logger.warning(
          "Test message",
          application: :otp_app,
          extra_pid: pid,
          extra_map: %{key: "value"},
          extra_tuple: {"el1", "el2"},
          extra_ref: ref
        )
      end)

    decoded_message = Jason.decode!(message)

    assert decoded_message["message"] == "Test message"
    assert decoded_message["application"] == "logstash_formatter"
    assert decoded_message["otp_application"] == "otp_app"
    assert decoded_message["@timestamp"] =~ ~r[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}\+00:00]
    assert decoded_message["level"] == "warning"
    assert decoded_message["module"] == "Elixir.#{inspect(__MODULE__)}"
    assert decoded_message["function"] == "#{to_string(test_name)}/1"
    assert decoded_message["extra_pid"] == inspect(pid)
    assert decoded_message["extra_ref"] == inspect(ref)
    assert decoded_message["extra_map"] == %{"key" => "value"}
    assert decoded_message["extra_tuple"] == ["el1", "el2"]

    for {key, val} <- decoded_message, is_list(val) do
      # Logstash is unable to parse fields of varied types
      assert all_of_same_type?(val),
             "Metadata element #{key} contains values of varied types: #{inspect(val)}"
    end
  end

  test "logs DateTime as a string" do
    datetime = DateTime.utc_now()

    message =
      capture_log(fn ->
        Logger.warning("Test message", datetime: datetime)
      end)

    decoded_message = Jason.decode!(message)

    assert decoded_message["datetime"] == DateTime.to_iso8601(datetime)
  end

  test "uses encoder protocol whenever possible" do
    datetime = DateTime.utc_now()
    struct = %CustomStruct{value: datetime}

    message =
      capture_log(fn ->
        Logger.warning("Test message", datetime: struct)
      end)

    decoded_message = Jason.decode!(message)

    assert decoded_message["datetime"] == DateTime.to_iso8601(datetime)
  end

  test "logs function as a string" do
    function = &:application_controller.format_log/1

    message =
      capture_log(fn ->
        Logger.warning("Test message", foo: function)
      end)

    decoded_message = Jason.decode!(message)
    assert decoded_message["foo"] == "&:application_controller.format_log/1"
  end

  test "logs file metadata as a string" do
    log_event =
      Jason.decode!(
        LogstashLoggerFormatter.format(
          :info,
          "message",
          @example_timestamp,
          Keyword.new(%{file: ~c"proc_lib.erl"})
        )
      )

    assert log_event["file"] == "proc_lib.erl"
  end

  test "logs unhandled structs" do
    message =
      capture_log(fn ->
        error = %KeyError{
          key: :on_terminate,
          message: nil,
          term: [
            [on_terminate: &:application_controller.format_log/1]
          ]
        }

        Logger.error("Oh no", error: error)
      end)

    decoded_message = Jason.decode!(message)

    assert decoded_message["error"] == %{
             "__struct__" => "Elixir.KeyError",
             "__exception__" => true,
             "key" => "on_terminate",
             "message" => nil,
             "term" => [[["on_terminate", "&:application_controller.format_log/1"]]]
           }
  end

  test "successfully logs MapSets containing tuples" do
    message =
      capture_log(fn ->
        Logger.info("message", foo: MapSet.new(bar: "baz"))
      end)

    assert message =~ ~r(bar,baz)
  end

  test "successfully logs maps containing structs as keys" do
    message =
      capture_log(fn ->
        Logger.info("message", foo: %{DateTime.utc_now() => "today"})
      end)

    assert message =~ "today"
    assert message =~ "unencodable map key"
  end

  test "truncates metadata" do
    message =
      capture_log(fn ->
        Logger.warning(
          "Test message",
          long_list: [
            "some long string in it 1",
            "some long string in it 2",
            "some long string in it 3",
            "some long string in it 4",
            "some long string in it 5",
            "some long string in it 6",
            "some long string in it 7",
            "some long string in it 8",
            "some long string in it 9",
            "some long string in it 10",
            "some long string in it 11",
            "some long string in it 12",
            "some long string in it 13",
            "some long string in it 14",
            "some long string in it 15",
            "some long string in it 16",
            "some long string in it 17",
            "some long string in it 18",
            "some long string in it 19",
            "some long string in it 20"
          ],
          long_list_with_maps: [
            %{thing: "some long string in it 1"},
            %{thing: "some long string in it 2"},
            %{thing: "some long string in it 3"},
            %{thing: "some long string in it 4"},
            %{thing: "some long string in it 5"},
            %{thing: "some long string in it 6"},
            %{thing: "some long string in it 7"},
            %{thing: "some long string in it 8"},
            %{thing: "some long string in it 9"},
            %{thing: "some long string in it 10"},
            %{thing: "some long string in it 11"},
            %{thing: "some long string in it 12"},
            %{thing: "some long string in it 13"},
            %{thing: "some long string in it 14"},
            %{thing: "some long string in it 15"},
            %{thing: "some long string in it 16"},
            %{thing: "some long string in it 17"},
            %{thing: "some long string in it 18"},
            %{thing: "some long string in it 19"},
            %{thing: "some long string in it 20"}
          ],
          short_list_with_very_long_string: [
            "Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo. Sed vel luctus " <>
              "felis. Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae scelerisque. Praesent sed " <>
              "viverra dolor, nec consectetur enim. Curabitur tincidunt posuere ante ac maximus. Vestibulum sit amet " <>
              "dui sagittis, tempus odio eu, consequat neque. Etiam urna libero, vestibulum nec turpis sit amet, " <>
              "condimentum venenatis leo. Donec quis ullamcorper mauris. Nunc eget felis velit. Cras molestie est non " <>
              "justo luctus, et cursus sem gravida. Sed pretium urna id ligula malesuada, venenatis vehicula massa " <>
              "dapibus. Nullam gravida nisl mauris, eu ultricies nisi condimentum pulvinar. Ut ac vestibulum turpis."
          ],
          big_map: %{
            a: "some long string in it 1",
            b: "some long string in it 2",
            c: "some long string in it 3",
            d: "some long string in it 4",
            e: "some long string in it 5",
            f: "some long string in it 6",
            g: "some long string in it 7",
            h: "some long string in it 8",
            i: "some long string in it 9",
            j: "some long string in it 10",
            k: "some long string in it 11",
            l: "some long string in it 12",
            m: "some long string in it 13",
            n: "some long string in it 14",
            o: "some long string in it 15",
            p: "some long string in it 16",
            q: "some long string in it 17",
            r: "some long string in it 18",
            s: "some long string in it 19",
            t: "some long string in it 20"
          },
          small_map: %{
            u:
              "Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo. Sed vel luctus " <>
                "felis. Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae scelerisque. Praesent sed " <>
                "viverra dolor, nec consectetur enim. Curabitur tincidunt posuere ante ac maximus. Vestibulum sit amet " <>
                "dui sagittis, tempus odio eu, consequat neque. Etiam urna libero, vestibulum nec turpis sit amet, " <>
                "condimentum venenatis leo. Donec quis ullamcorper mauris. Nunc eget felis velit. Cras molestie est non " <>
                "justo luctus, et cursus sem gravida. Sed pretium urna id ligula malesuada, venenatis vehicula massa " <>
                "dapibus. Nullam gravida nisl mauris, eu ultricies nisi condimentum pulvinar. Ut ac vestibulum turpis."
          },
          nested_map: %{
            v: "some long string in it",
            w:
              "Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo.",
            hash: %{
              list: [
                "some long string in it 1",
                "some long string in it 2"
              ],
              something: %{
                a: "some long string in it 1",
                b: "some long string in it 2"
              }
            }
          },
          number: 1,
          atom: :atom,
          long_string:
            "Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo. Sed vel luctus " <>
              "felis. Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae scelerisque. Praesent sed " <>
              "viverra dolor, nec consectetur enim. Curabitur tincidunt posuere ante ac maximus. Vestibulum sit amet " <>
              "dui sagittis, tempus odio eu, consequat neque. Etiam urna libero, vestibulum nec turpis sit amet, " <>
              "condimentum venenatis leo. Donec quis ullamcorper mauris. Nunc eget felis velit. Cras molestie est non " <>
              "justo luctus, et cursus sem gravida. Sed pretium urna id ligula malesuada, venenatis vehicula massa " <>
              "dapibus. Nullam gravida nisl mauris, eu ultricies nisi condimentum pulvinar. Ut ac vestibulum turpis."
        )
      end)

    decoded_message = Jason.decode!(message)

    assert decoded_message["long_list"] == [
             "some long string in it 1",
             "some long string in it 2",
             "some long string in it 3",
             "some long string in it 4",
             "some long string in it 5",
             "some long string in it 6",
             "-pruned-"
           ]

    assert decoded_message["long_list_with_maps"] == [
             %{"thing" => "some long string in it 1"},
             %{"thing" => "some long string in it 2"},
             %{"thing" => "some long string in it 3"},
             %{"thing" => "some long string in it 4"},
             %{"-pruned-" => true}
           ]

    assert decoded_message["short_list_with_very_long_string"] == [
             "\"Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo. Sed vel luctus felis. " <>
               "Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae scelerisque. Praesent s (-pruned-)"
           ]

    assert decoded_message["big_map"] == %{
             "a" => "some long string in it 1",
             "b" => "some long string in it 2",
             "c" => "some long string in it 3",
             "d" => "some long string in it 4",
             "e" => "some long string in it 5",
             "-pruned-" => true
           }

    assert decoded_message["small_map"] == %{
             "u" =>
               "\"Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in dignissim justo. Sed vel luctus " <>
                 "felis. Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae scelerisque. Praesent s (-pruned-)"
           }

    assert decoded_message["nested_map"] == %{
             "hash" => %{
               "list" => [
                 "some long string in it 1",
                 "some long string in it 2"
               ],
               "something" => %{
                 "a" => "some long string in it 1",
                 "b" => "some long string in it 2"
               }
             },
             "v" => "some long string in it",
             "-pruned-" => true
           }

    assert decoded_message["number"] == 1
    assert decoded_message["atom"] == "atom"

    assert decoded_message["long_string"] ==
             "\"Nam elementum iaculis nisi, vitae lacinia erat lacinia id. Proin in " <>
               "dignissim justo. Sed vel luctus felis. Vestibulum pulvinar tempor commodo. Aenean imperdiet eget nibh vitae " <>
               "scelerisque. Praesent s (-pruned-)"
  end

  test "prunes invalid UTF-8 bytes in message and metadata" do
    invalid_utf8_bytes = <<97, 131, 255>>
    invalid_utf8_bytes_pruned = Logger.Formatter.prune(invalid_utf8_bytes)

    message =
      capture_log(fn ->
        Logger.warning(
          invalid_utf8_bytes,
          key1: invalid_utf8_bytes,
          key2: {:a, invalid_utf8_bytes}
        )
      end)

    decoded_message = Jason.decode!(message)

    assert %{
             "message" => ^invalid_utf8_bytes_pruned,
             "key1" => ^invalid_utf8_bytes_pruned,
             "key2" => ["a", ^invalid_utf8_bytes_pruned]
           } = decoded_message
  end

  test "logs trimmed crash reports" do
    log_event =
      Jason.decode!(
        LogstashLoggerFormatter.format(
          :error,
          @phoenix_crash_example.message,
          @example_timestamp,
          @phoenix_crash_example.metadata
        )
      )

    refute Map.has_key?(log_event, "crash_reason")
    refute Map.has_key?(log_event, "initial_call")
    assert String.contains?(log_event["message"], "SomeError")
    refute String.contains?(log_event["message"], @secret_value_example)
  end

  defp all_of_same_type?(list) when is_list(list) do
    list |> Enum.map(&BasicTypes.typeof(&1)) |> Enum.uniq() |> Enum.count() == 1
  end
end
