defmodule MusicCast.UPnP.AVTransport do
  @moduledoc """
  Defines a “common” model for A/V transport control suitable for a UPnP generic user interface.
  """

  use MusicCast.UPnP.Service, type: "AVTransport:1"

  defmodule URIMetaData do
    @moduledoc false
    @enforce_keys [:mimetype]
    defstruct [:title, :artist, :album, :album_cover_url, :mimetype, duration: 0]
  end

  def set_av_transport_uri(control_url, instance_id, current_uri, %URIMetaData{} = current_uri_meta_data) do
    super(control_url, instance_id, current_uri, didl_lite(current_uri, current_uri_meta_data))
  end

  def set_next_av_transport_uri(control_url, instance_id, next_uri, %URIMetaData{} = next_uri_meta_data) do
    super(control_url, instance_id, next_uri, didl_lite(next_uri, next_uri_meta_data))
  end

  #
  # Helpers
  #

  defp dlna_content_features("audio/mp4"), do: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320;DLNA.ORG_FLAGS=9D300000000000000000000000000000"

  defp didl_lite(url, meta) do
    to_string([
      ~s(<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:dc="http://purl.org/dc/elements/1.1/">),
        ~s(<item id="f-0" parentID="0" restricted="0">),
          ~s(<upnp:class>object.item.audioItem.musicTrack</upnp:class>),
          didl_fields(meta),
          ~s(<res protocolInfo="#{dlna_content_features(meta.mimetype)}" duration="#{duration(meta.duration)}">#{url}</res>),
        ~s(</item>),
      ~s(</DIDL-Lite>)])
  end

  defp didl_fields(meta) do
    meta
    |> Map.from_struct()
    |> Map.drop([:duration, :mimetype])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map(&didl_field/1)
  end

  defp didl_field({:title, title}), do: "<dc:title>#{title}</dc:title>"
  defp didl_field({:album, album}), do: "<upnp:album>#{album}</upnp:album>"
  defp didl_field({:album_cover_url, url}), do: "<upnp:albumArtURI>#{url}</upnp:albumArtURI>"
  defp didl_field({:artist, artist}), do: "<upnp:artist>#{artist}</upnp:artist>"

  defp duration(duration) do
    hours = :io_lib.format("~2..0B", [div(duration, 3_600)])
    minutes = :io_lib.format("~2..0B", [div(duration, 60)])
    seconds = :io_lib.format("~2..0B", [Integer.mod(duration, 60)])
    "#{hours}:#{minutes}:#{seconds}"
  end
end
