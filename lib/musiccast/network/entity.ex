defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for working with MusicCast entities.
  """

  use GenServer

  require Logger

  alias MusicCast.ExtendedControl, as: YXC

  defstruct host: nil,
            device_id: nil,
            network_name: nil,
            status: nil,
            playback: nil

  @doc """
  Starts an entity as part of a supervision tree.
  """
  def start_link(addr, options \\ []) do
    GenServer.start_link(__MODULE__, addr, options)
  end

  @doc """
  Looks-up the value for the given key(s).
  """
  def lookup(pid, keys) do
    GenServer.call(pid, {:lookup, keys})
  end

  #
  # Callbacks
  #

  def init(addr) do
    with host <- to_string(:inet_parse.ntoa(addr)),
         {:ok, %{"device_id" => device_id}} <- YXC.get_device_info(host),
         {:ok, %{"network_name" => network_name}} <- YXC.get_network_status(host),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, _} <- register_device(device_id, addr) do
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
    {:reply, List.to_tuple(attrs), state}
  end

  #
  # Helpers
  #

  defp register_device(device_id, _addr) do
    Registry.register(MusicCast.Registry, device_id, nil)
  end
end
