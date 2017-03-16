defmodule MusicCast.Network do
  @moduledoc """
  A module for supervising a network of MusicCast devices.
  """

  use Supervisor

  alias MusicCast.Network.Entity

  @doc """
  Starts a network as part of a supervision tree.
  """
  @spec start_link(Keyword.t) :: Supervisor.on_start
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [], options)
  end

  @doc """
  Adds a new device to the network.
  """
  @spec add_device(MusicCast.Network.Entity.ip_address) :: Supervisor.on_start_child
  def add_device(addr) do
    Supervisor.start_child(__MODULE__, [addr])
  end

  @doc """
  Subscribes the current process to notifications from the given device.
  """
  @spec subscribe(MusicCast.Network.Entity.device_id) :: {:ok, pid} | {:error, {:already_registered, pid}}
  def subscribe(device_id) do
    Registry.register(MusicCast.PubSub, device_id, nil)
  end

  @doc """
  Unsubscribes the current process from notification from the given device.
  """
  @spec unsubscribe(MusiCast.Network.device_id) :: :ok
  def unsubscribe(device_id) do
    Registry.unregister(MusicCast.PubSub, device_id)
  end

  @doc """
  Returns the PID for the registered device id.
  """
  @spec whereis(MusicCast.Network.Entity.device_id) :: {pid, MusicCast.Network.Entity.ip_address} | nil
  def whereis(device_id) do
    case Registry.lookup(MusicCast.Registry, device_id) do
      [pair] -> pair
      [] -> nil
    end
  end

  @doc """
  Returns a list of all registered devices.
  """
  @spec which_devices() :: [pid]
  def which_devices do
    Enum.map(Supervisor.which_children(__MODULE__), &elem(&1, 1))
  end

  @doc """
  Returns a list of all registered devices and their attributes.
  """
  @spec which_devices(MusicCast.Network.Entity.lookup_opts) :: [tuple]
  def which_devices(keys) do
    Enum.map(which_devices(), &lookup(&1, keys))
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

  defp lookup(pid, keys) do
    pid
    |> Entity.__lookup__(keys)
    |> List.wrap()
    |> List.to_tuple()
    |> Tuple.insert_at(0, pid)
  end
end
