defmodule MusicCast.Network do
  @moduledoc """
  A module for supervising a network of MusicCast™ devices.

  The network is the heart of this MusicCast application. It is responsible for discovering
  devices on the local network (see `MusicCast.UPnP.SSDPClient`), keeping their state synchronized
  whenever a device's state is changing and broadcasting network topology changes and device change events.

  Also, the network act as a global registry for running `MusicCast.Network.Entity` processes. You can find a device on the registry
  with `whereis/1`. To get a list of registered devices, see `which_devices/1`.

  You also have the possibility to subscribe to network topoligy changes (for example, when a new device is discovered
  or when a device goes offline). Additionally, you can subscribe to a device's changefeed directly.
  See `subscribe/1` and `unsubscribe/1` for more details.
  """

  use Supervisor

  alias MusicCast.Network.Entity

  @doc """
  Starts a network supervisor as part of a supervision tree.
  """
  @spec start_link(Keyword.t) :: Supervisor.on_start
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [], options)
  end

  defdelegate stop(pid), to: Supervisor

  @doc """
  Adds a new device entity to the network.
  """
  @spec add_device(MusicCast.Network.Entity.ip_address, MusicCast.Network.Entity.upnp_desc) :: Supervisor.on_start_child
  def add_device(addr, upnp_desc) do
    Supervisor.start_child(__MODULE__, [addr, upnp_desc])
  end

  @doc """
  Subscribes the current process to notifications from the given entity.

  You can subscribe to network topology changes:

      iex> MusicCast.subscribe(:network)
      {:ok, #PID<0.80.0>}
      iex> flush()
      {:extended_control, :network, %MusicCast.Network.Entity{}}

  Or to subscribe to status notifications from a specific device:

      iex> MusicCast.subscribe("00A0DEDCF73E")
      {:ok, #PID<0.200.0>}
      iex> flush()
      {:extended_control, "00A0DEDCF73E", %{}}
  """
  @spec subscribe(MusicCast.Network.Entity.device_id | pid | :network) :: {:ok, pid} | {:error, {:not_found, MusicCast.Network.Entity.device_id | pid}}
  def subscribe(entity \\ :network)

  def subscribe(:network) do
    {:ok, _} = Registry.register(MusicCast.PubSub, "network", nil)
    {:ok, Process.whereis(MusicCast.Network)}
  end

  def subscribe(pid) when is_pid(pid) do
    case Registry.keys(MusicCast.Registry, pid) do
      [device_id] ->
        {:ok, _} = Registry.register(MusicCast.PubSub, device_id, nil)
        {:ok, pid}
      [] ->
        {:error, {:not_found, pid}}
    end
  end

  def subscribe(device_id) do
    case whereis(device_id) do
      {pid, _host} ->
        {:ok, _} = Registry.register(MusicCast.PubSub, device_id, nil)
        {:ok, pid}
      nil ->
        {:error, {:not_found, device_id}}
    end
  end

  @doc """
  Unsubscribes the current process from notification from the given entity.
  """
  @spec unsubscribe(MusiCast.Network.Entity.device_id | pid | :network) :: :ok
  def unsubscribe(entity \\ :network)

  def unsubscribe(:network) do
    Registry.unregister(MusicCast.PubSub, "network")
  end

  def unsubscribe(pid) when is_pid(pid) do
    case Registry.keys(MusicCast.Registry, pid) do
      [device_id] ->
        unsubscribe(device_id)
      [] ->
        :ok
    end
  end

  def unsubscribe(device_id) do
    Registry.unregister(MusicCast.PubSub, device_id)
  end

  @doc """
  Returns the PID and the host for the registered device id.
  """
  @spec whereis(MusicCast.Network.Entity.device_id) :: {pid, MusicCast.Network.Entity.ip_address} | nil
  def whereis(device_id) do
    case Registry.lookup(MusicCast.Registry, device_id) do
      [pair] -> pair
      [] -> nil
    end
  end

  @doc """
  Looks-up the given key(s) for the given entity.
  """
  @spec lookup(MusicCast.Network.Entity.device_id | pid, MusicCast.Network.Entity.lookup_keys) :: MusicCast.Network.Entity.lookup_results
  def lookup(entity, keys \\ :all)

  def lookup(pid, keys) when is_pid(pid), do: Entity.__lookup__(pid, keys)
  def lookup(device_id, keys) do
    case whereis(device_id) do
      {pid, _host} -> lookup(pid, keys)
      nil -> nil
    end
  end

  @doc """
  Returns a list of all registered devices.

  If you pass `:lazy` to this function, it will return a list of `{pid, device_id}` tuples:

      iex> MusicCast.which_devices(:lazy)
      [{#PID<0.200.0>, "00A0DEDCF73E"}]

  Otherwise, you can pass a list of keys to lookup:

      iex> MusicCast.which_devices([:network_name, :host])
      [{#PID<0.200.0>, "Schlafzimmer", "192.168.0.63"}]

  See `MusicCast.Network.Entity.__lookup__/2` for more informations about available lookup options.
  """
  @spec which_devices(MusicCast.Network.Entity.lookup_keys | :lazy) :: [tuple]
  def which_devices(keys \\ :lazy)

  def which_devices(:lazy) do
    Enum.map(fetch_devices(), &{&1, List.first(Registry.keys(MusicCast.Registry, &1))})
  end

  def which_devices(keys) do
    Enum.map(fetch_devices(), &lookup_device(&1, keys))
  end

  #
  # Callbacks
  #

  def init([]) do
    children = List.wrap(worker(Entity, []))
    supervise(children, strategy: :simple_one_for_one)
  end

  #
  # Helpers
  #

  defp fetch_devices do
    Enum.map(Supervisor.which_children(__MODULE__), &elem(&1, 1))
  end

  defp lookup_device(pid, keys) do
    pid
    |> Entity.__lookup__(keys)
    |> List.wrap()
    |> List.to_tuple()
    |> Tuple.insert_at(0, pid)
  end
end
