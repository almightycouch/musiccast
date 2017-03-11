defmodule MusicCast.Network.EventListener do
  @moduledoc """
  A module for receiving Yamaha Extended Control (YXC) Unicast events.
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

  @doc """
  Subscribes the current process to a device changefeed.
  """
  @spec subscribe(MusicCast.Network.Entity.device_id, Keyword.t) :: {:ok, pid} | {:error, {:already_registered, pid}}
  def subscribe(device_id, options \\ []) do
    zone = Keyword.get(options, :zone)
    Registry.register(MusicCast.PubSub, device_id, zone)
  end

  @doc """
  Unsubscribes the current process from a device changefeed.
  """
  @spec unsubscribe(MusicCast.Network.Entity.device_id) :: :ok
  def unsubscribe(device_id) do
    Registry.unregister(MusicCast.PubSub, device_id)
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
    Registry.dispatch(MusicCast.PubSub, payload["device_id"], fn subscribers ->
      for {pid, zone} <- subscribers, is_nil(zone) || Map.has_key?(payload, zone) do
        send(pid, {:yxc_event, payload})
      end
    end)
  end
end
