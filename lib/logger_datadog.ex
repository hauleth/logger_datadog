defmodule LoggerDatadog do
  @moduledoc """
  Documentation for LoggerDatadog.
  """

  @behaviour :gen_event

  defstruct [:api_token, :service, socket: []]

  @impl true
  def init(__MODULE__), do: init({__MODULE__, []})

  def init({__MODULE__, opts}) do
    system_opts = Application.get_env(:logger, :datadog) || []

    {:ok, configure(Keyword.merge(system_opts, opts))}
  end

  @impl true
  def handle_call({:configure, options}, state),
    do: {:ok, :ok, configure(options, state)}

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

  defp configure(opts, state \\ %__MODULE__{}) do
    _ = for {mod, sock} <- state.socket, do: mod.close(sock)

    token = Keyword.fetch!(opts, :api_token)
    service = Keyword.get(opts, :service, "elixir")
    tls = Keyword.get(opts, :tls, false)
    endpoint =
      case Keyword.get(opts, :endpoint, "intake.logs.datadoghq.com") do
        binary when is_binary(binary) -> String.to_charlist(binary)
        other -> other
      end
    port = Keyword.get(opts, :port, 10514)

    {:ok, tcp_socket} = :gen_tcp.connect(endpoint, port, [:binary])

    socket =
      if tls do
        options =
          if is_list(tls) do
            tls
          else
            [handshake: :full]
          end

        {:ok, socket} = :ssl.connect(tcp_socket, options)

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
