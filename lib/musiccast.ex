defmodule MusicCast do
  defdelegate add_device(addr), to: MusicCast.Network
  defdelegate discover, to: MusicCast.SSDPClient
  defdelegate whereis(device_id), to: MusicCast.Network
  defdelegate which_devices, to: MusicCast.Network
  defdelegate which_devices(lookup_keys), to: MusicCast.Network
end
