defprotocol MusicCast.UPnP.Serializable do
  @moduledoc """
  Serializable protocol used by `MusicCast.UPnP.Service` in order to cast UPnP notifications.
  """

  @doc """
  Casts the given UPnP event.
  """
  @fallback_to_any true
  @spec cast(Enum.t) :: Enum.t
  def cast(event)
end


defimpl MusicCast.UPnP.Serializable, for: Any do
  def cast(event), do: event
end
