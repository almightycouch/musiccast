defmodule MusicCast.Network do
  @moduledoc """
  A module for supervising a network of MusicCast™ devices.

  The network is the heart of this MusicCast application. It is responsible for discovering
  devices on the local network (see `MusicCast.UPnP.SSDPClient`) and keeping their state synchronized.

  You have the possibility to subscribe to network topoligy changes (for example, when a new device is discovered
  or when a device goes offline). Additionally, you can subscribe to a device's changefeed directly.
  See `subscribe/1` and `unsubscribe/1` for more details.

  Also, the network act as a global registry for running `MusicCast.Network.Entity` processes. You can find a device on the registry
  with `whereis/1`. To get a list of registered devices, see `which_devices/1`.
  """

  use Supervisor

  alias MusicCast.Network.Entity

  @type device_id :: String.t

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
  @spec add_device(MusicCast.Network.Entity.ip_address, MusicCast.UPnP.Service.t) :: Supervisor.on_start_child
  def add_device(addr, upnp_desc) do
    Supervisor.start_child(__MODULE__, [addr, upnp_desc])
  end

  @doc """
  Returns the value(s) for the given lookup key(s) from the given device id.

  See `MusicCast.Network.Entity.__lookup__/2` for more details.
  """
  @spec lookup(device_id, MusicCast.Network.Entity.lookup_query) :: any
  def lookup(device_id, keys \\ :all)
  def lookup(pid, keys) when is_pid(pid), do: Entity.__lookup__(pid, keys)
  def lookup(device_id, keys) do
    if pid = whereis(device_id), do: lookup(pid, keys)
  end

  @doc """
  Subscribes the current process to notifications from the given entity.

  You can subscribe to network topology changes:

      iex> MusicCast.subscribe(:network)
      {:ok, #PID<0.80.0>}
      iex> flush()
      {:musiccast, :online, %MusicCast.Network.Entity{}}

  Or subscribe to status notifications from a specific device:

      iex> MusicCast.subscribe("00A0DEDCF73E")
      {:ok, #PID<0.200.0>}
      iex> flush()
      {:musiccast, :update, "00A0DEDCF73E", %{}}
  """
  @spec subscribe(:network | device_id) :: {:ok, pid}
  def subscribe(entity)
  def subscribe(:network),  do: Registry.register(MusicCast.PubSub, "network", nil)
  def subscribe(device_id), do: Registry.register(MusicCast.PubSub, device_id, nil)

  @doc """
  Unsubscribes the current process from notification from the given entity.
  """
  @spec unsubscribe(:network | device_id) :: :ok
  def unsubscribe(entity)
  def unsubscribe(:network),  do: Registry.unregister(MusicCast.PubSub, "network")
  def unsubscribe(device_id), do: Registry.unregister(MusicCast.PubSub, device_id)

  @doc """
  Returns the PID for the registered device id or `nil` if the given `device_id` is not available.
  """
  @spec whereis(device_id) :: pid | nil
  def whereis(device_id) do
    case Registry.lookup(MusicCast.Registry, device_id) do
      [{pid, _host}] -> pid
      [] -> nil
    end
  end

  @doc """
  Returns a list of all registered devices.

  If you pass `:lazy` to this function, it will return a list of `{pid, device_id}` tuples:

      iex> MusicCast.which_devices(:lazy)
      [{#PID<0.200.0>, "00A0DEDCF73E"}]

  Otherwise, you can specify a list of keys to lookup for:

      iex> MusicCast.which_devices([:network_name, :host])
      [{#PID<0.200.0>, "Schlafzimmer", "192.168.0.63"}]

  See `lookup/2` for more informations about available lookup options.
  """
  @spec which_devices(:lazy | MusicCast.Network.Entity.lookup_query) :: [tuple]
  def which_devices(keys \\ :lazy)
  def which_devices(:lazy), do: Enum.map(fetch_devices(), &{&1, List.first(Registry.keys(MusicCast.Registry, &1))})
  def which_devices(keys),  do: Enum.map(fetch_devices(), &{&1, Entity.__lookup__(&1, keys)})

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
end
