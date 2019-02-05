defmodule LoggerDatadog do
  @moduledoc """
  Documentation for LoggerDatadog.
  """

  @behaviour :gen_event

  defstruct [:api_token, :service, socket: []]

  @impl true
  def init({__MODULE__, token}) do
    opts = Application.get_env(:logger, :datadog)

    {:ok, configure(token, opts)}
  end

  @impl true
  def handle_call({:configure, opts}, %{api_token: token} = state) do
    {:ok, :ok, configure(token, opts, state)}
  end

  @impl true
  def handle_event({level, gl, {Logger, msg, ts, meta}}, state) when gl != node() do
    {mod, socket} = hd(state.socket)
    {:ok, hostname} = :inet.gethostname()

    data =
      Jason.encode_to_iodata!(%{
        "message" => msg,
        "metadata" => Map.new(normalise(meta)),
        "level" => Atom.to_string(level),
        "timestamp" => ts_to_iso(ts),
        "source" => "elixir",
        "host" => to_string(hostname),
        "service" => state.service
      })

    :ok = mod.send(socket, [state.api_token, " ", data, ?\r, ?\n])

    {:ok, state}
  end

  def handle_event(:flush, state), do: {:ok, state}

  def handle_event(event, _state) do
    IO.inspect(event)

    raise "Unknown event"
  end

  defp configure(token, opts, state \\ %__MODULE__{}) do
    _ = for {mod, sock} <- state.socket, do: mod.close(sock)

    service = Keyword.get(opts, :service, "elixir")
    tls = Keyword.get(opts, :tls, true)
    endpoint = Keyword.get(opts, :endpoint, "intake.logs.datadoghq.com")
    port = Keyword.get(opts, :port, 10516)

    {:ok, tcp_socket} = :gen_tcp.connect(to_charlist(endpoint), port, [:binary])

    socket =
      if tls do
        {:ok, socket} = :ssl.connect(tcp_socket, handshake: :full)

        [{:ssl, socket}, {:gen_tcp, tcp_socket}]
      else
        [{:gen_tcp, tcp_socket}]
      end

    struct(state, socket: socket, api_token: token, service: service)
  end

  defp ts_to_iso({{year, month, day}, {hour, min, sec, msec}}) do
    List.to_string(
      :io_lib.format('~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B.~3..0BZ', [
        year,
        month,
        day,
        hour,
        min,
        sec,
        msec
      ])
    )
  end

  defp normalise(list) when is_list(list) do
    if Keyword.keyword?(list) do
      Map.new(list, &normalise/1)
    else
      Enum.map(list, &normalise/1)
    end
  end

  defp normalise(map) when is_map(map), do: Map.new(map, &normalise/1)
  defp normalise({atom, key}), do: {atom, normalise(key)}
  defp normalise(string) when is_binary(string), do: string
  defp normalise(other), do: inspect(other)
end
