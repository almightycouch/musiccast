defmodule MusicCast.Network do
  @moduledoc """
  A module for supervising a network of MusicCast devices.
  """

  use Supervisor

  alias MusicCast.Network.Entity

  @doc """
  Starts a network as part of a supervision tree.
  """
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, [], options)
  end

  @doc """
  Adds a new device to the network.
  """
  def add_device(addr) do
    Supervisor.start_child(__MODULE__, [addr])
  end

  @doc """
  Returns the PID for the registered device id.
  """
  def whereis(device_id) do
    case Registry.lookup(MusicCast.Registry, device_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Returns a list of all registered devices on the network.
  """
  def which_devices do
    Enum.map(Supervisor.which_children(__MODULE__), &elem(&1, 1))
  end

  def which_devices(lookup_keys) do
    Enum.map(which_devices(), &Tuple.append(Entity.lookup(&1, lookup_keys), &1))
  end

  #
  # Callbacks
  #

  def init([]) do
    children = List.wrap(worker(Entity, []))
    supervise(children, strategy: :simple_one_for_one)
  end
end
