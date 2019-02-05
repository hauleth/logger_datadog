defmodule Listener do
  use GenServer

  @enforce_keys [:pid, :port]
  defstruct [:pid, :port, :lsocket, :socket, buffer: ""]

  def start_link(config), do: GenServer.start_link(__MODULE__, config)

  def init(config) do
    state = struct(__MODULE__, config)

    {:ok, lsocket} = :gen_tcp.listen(state.port, [:binary, packet: 0])

    {:ok, struct(state, lsocket: lsocket), {:continue, :listen}}
  end

  def handle_continue(:listen, state) do
    {:ok, socket} = :gen_tcp.accept(state.lsocket, 1000)

    {:noreply, struct(state, socket: socket)}
  end

  def handle_info({:tcp, _socket, data}, state) do
    buf = state.buffer <> data
    {leftover, chunks} = split(buf)

    for chunk <- chunks do
      send(state.pid, {:listener, chunk})
    end

    {:noreply, struct(state, buffer: leftover)}
  end

  def terminate(_, state) do
    if state.socket, do: :gen_tcp.close(state.socket)

    :gen_tcp.close(state.lsocket)
  end

  defp split(data, chunks \\ [""])
  defp split(<<>>, [left | chunks]), do: {left, Enum.reverse(chunks)}

  defp split(<<"\r\n", rest::binary>>, chunks), do: split(rest, ["" | chunks])

  defp split(<<h, rest::binary>>, [curr | chunks]),
    do: split(rest, [<<curr::binary, h>> | chunks])
end
