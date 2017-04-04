defmodule MusicCast do
  @moduledoc """
  A Yamaha MusicCast™ implementation supporting SSDP discovery and Yamaha's YXC API.
  """

  defdelegate add_device(addr, upnp_desc), to: MusicCast.Network
  defdelegate discover, to: MusicCast.UPnP.SSDPClient
  defdelegate subscribe(device_id \\ :network), to: MusicCast.Network
  defdelegate unsubscribe(device_id \\ :network), to: MusicCast.Network
  defdelegate whereis(device_id), to: MusicCast.Network
  defdelegate which_devices(lookup_keys \\ :lazy), to: MusicCast.Network
end
