defmodule MusicCast do
  @moduledoc """
  A Yamaha MusicCast™ implementation supporting UPnP A/V and Yamaha's YXC API.
  """

  defdelegate discover, to: MusicCast.UPnP.SSDPClient
  defdelegate subscribe(entity), to: MusicCast.Network
  defdelegate unsubscribe(entity), to: MusicCast.Network
  defdelegate lookup(entity, lookup_key \\ :all), to: MusicCast.Network
  defdelegate whereis(device_id), to: MusicCast.Network
  defdelegate which_devices(lookup_keys \\ :lazy), to: MusicCast.Network
end
