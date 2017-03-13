defmodule MusicCast.Network.EventListener do
  @moduledoc """
  A module for receiving Yamaha Extended Control (YXC) unicast events.
  """

  use GenServer

  @doc """
  Starts a server as part of a supervision tree.
  """
  @spec start_link(Keywort.t) :: GenServer.on_start
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
	GenServer.start_link(__MODULE__, [], options)
  end

  #
  # Callbacks
  #

  def init([]) do
	case :gen_udp.open(41100) do
      {:ok, socket} -> {:ok, socket}
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_info({:udp, _socket, _ip, _port, data}, socket) do
    case Poison.decode(data) do
      {:ok, payload} -> dispatch(payload)
    end
	{:noreply, socket}
  end

  #
  # Helpers
  #

  defp dispatch(payload) do
    if {pid, _host} = MusicCast.Network.whereis(payload["device_id"]) do
      send(pid, {:yxc_event, Map.drop(payload, ["device_id"])})
    end
  end
end