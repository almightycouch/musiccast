defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for managing MusicCast enabled devices.
  """

  use GenServer

  require Logger

  alias MusicCast.ExtendedControl, as: YXC

  defstruct host: nil,
            device_id: nil,
            network_name: nil,
            status: nil,
            playback: nil

  @type ip_address :: {0..255, 0..255, 0..255, 0..255}

  @type device_id :: String.t

  @type lookup_opt :: :host | :device_id | :network_name | :status | :playback
  @type lookup_opts :: [lookup_opt] | lookup_opt

  @doc """
  Starts an entity as part of a supervision tree.
  """
  @spec start_link(ip_address, Keyword.t) :: GenServer.on_start
  def start_link(addr, options \\ []) do
    GenServer.start_link(__MODULE__, addr, options)
  end

  @doc """
  Looks-up the value for the given key(s).
  """
  @spec lookup(GenServer.server, lookup_opts) :: [term] | term
  def lookup(pid, keys) do
    GenServer.call(pid, {:lookup, keys})
  end

  #
  # Callbacks
  #

  def init(addr) do
    headers = [
      {"X-AppName", "MusicCast/1.50"},
      {"X-AppPort", 41100}
    ]
    with host <- to_string(:inet_parse.ntoa(addr)),
         {:ok, %{"device_id" => device_id}} <- YXC.get_device_info(host, headers: headers),
         {:ok, %{"network_name" => network_name}} <- YXC.get_network_status(host),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, _} <- Registry.register(MusicCast.Registry, device_id, nil),
         {:ok, _} <- MusicCast.Network.EventListener.subscribe(device_id) do
      {:ok, %__MODULE__{host: host,
                        device_id: device_id,
                        network_name: network_name,
                        status: status,
                        playback: playback}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:lookup, keys}, _from, state) do
    attrs = for key <- List.wrap(keys), Map.has_key?(state, key), do: Map.fetch!(state, key)
    if is_list(keys),
      do: {:reply, attrs, state},
    else: {:reply, List.first(attrs), state}
  end

  def handle_info({:yxc_event, _payload}, state) do
    {:noreply, state}
  end
end
