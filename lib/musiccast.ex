defmodule MusicCast do
  @moduledoc """
  A Yamaha MusicCast™ implementation supporting SSDP discovery and Yamaha's YXC API.
  """

  @spec add_device(MusicCast.Network.Entity.ip_address) :: Supervisor.on_start_child
  defdelegate add_device(addr), to: MusicCast.Network

  @spec discover() :: :ok
  defdelegate discover, to: MusicCast.SSDPClient

  @spec whereis(MusicCast.Network.Entity.device_id) :: pid | nil
  defdelegate whereis(device_id), to: MusicCast.Network

  @spec which_devices() :: [pid]
  defdelegate which_devices, to: MusicCast.Network

  @spec which_devices(MusicCast.Network.Entity.lookup_opts) :: [tuple]
  defdelegate which_devices(lookup_keys), to: MusicCast.Network
end
