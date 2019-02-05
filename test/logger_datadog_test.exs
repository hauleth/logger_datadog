defmodule LoggerDatadogTest do
  use ExUnit.Case
  use ExUnitProperties

  require Logger

  @moduletag capture_log: true

  setup do
    port = 6000 + :rand.uniform(500)
    token = "dd_token_#{port}"

    logger = {LoggerDatadog, api_token: token, port: port}

    {:ok, _pid} = start_supervised({Listener, port: port, pid: self()})
    {:ok, _} = Logger.add_backend(logger, flush: true)

    on_exit fn ->
      Logger.remove_backend(logger, flush: true)
    end

    [token: token]
  end

  defp log do
    gen all msg <- string(:ascii),
      lvl <- one_of(~w[debug info warn error]a),
      do: {lvl, msg}
  end

  defp metadata do
    values = tuple({atom(:alphanumeric), string(:ascii)})

    uniq_list_of(
      values,
      uniq_fun: &elem(&1, 0),
      min_length: 1)
  end

  property "message has value of logged message", %{token: token} do
    check all {lvl, msg} <- log() do
      Logger.log(lvl, msg)

      assert_receive {:listener, data}
      assert {:ok, {^token, json}} = parse(data)
      assert %{"message" => ^msg} = json
    end
  end

  property "contains proper metadata", %{token: token} do
    check all {lvl, msg} <- log(),
      metadata <- metadata()
    do
      Logger.log(lvl, msg, metadata)

      assert_receive {:listener, data}
      assert {:ok, {^token, json}} = parse(data)
      assert %{"metadata" => meta} = json

      for {key, value} <- metadata do
        assert value == Map.get(meta, Atom.to_string(key))
      end
    end
  end

  defp parse(data) do
    with [token, raw] <- String.split(data, " ", parts: 2, trim: true),
         {:ok, json} <- Jason.decode(raw)
    do
      {:ok, {token, json}}
    else
      _ -> :error
    end
  end
end
