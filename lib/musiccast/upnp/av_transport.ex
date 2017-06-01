defmodule MusicCast.UPnP.AVTransport do
  @moduledoc """
  Defines a “common” model for *UPnP A/V transport* control suitable for a UPnP generic user interface.
  """

  use MusicCast.UPnP.Service, type: "AVTransport:1"

  alias MusicCast.UPnP.AVMusicTrack

  def set_av_transport_uri(control_url, instance_id, current_uri, nil), do: super(control_url, instance_id, current_uri, "")
  def set_av_transport_uri(control_url, instance_id, current_uri, items) when is_list(items), do: super(control_url, instance_id, current_uri, AVMusicTrack.didl_encode(items))
  def set_av_transport_uri(control_url, instance_id, current_uri, meta) when is_binary(meta), do: super(control_url, instance_id, current_uri, meta)
  def set_av_transport_uri(control_url, instance_id, current_uri, %AVMusicTrack{} = current_uri_meta_data) do
    super(control_url, instance_id, current_uri, AVMusicTrack.didl_encode([{current_uri, current_uri_meta_data}]))
  end

  def set_next_av_transport_uri(control_url, instance_id, next_uri, nil), do: super(control_url, instance_id, next_uri, "")
  def set_next_av_transport_uri(control_url, instance_id, next_uri, meta) when is_binary(meta), do: super(control_url, instance_id, next_uri, meta)
  def set_next_av_transport_uri(control_url, instance_id, next_uri, %AVMusicTrack{} = next_uri_meta_data) do
    super(control_url, instance_id, next_uri, AVMusicTrack.didl_encode([{next_uri, next_uri_meta_data}]))
  end
end

defimpl MusicCast.UPnP.Serializable, for: MusicCast.UPnP.AVTransport do

  import MusicCast.UPnP.AVMusicTrack, only: [didl_decode: 1]

  def cast(event) do
    event
    |> decode_didl(:current_track_meta_data)
    |> decode_didl(:next_track_meta_data)
    |> decode_didl(:av_transport_uri_meta_data)
    |> decode_didl(:next_av_transport_uri_meta_data)
  end

  defp decode_didl(event, key) do
    Map.update(event, key, nil, fn item ->
      case didl_decode(item) do
        [item] -> item
         items -> items
      end
    end)
  end
end
