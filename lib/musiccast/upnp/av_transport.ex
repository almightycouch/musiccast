defmodule MusicCast.UPnP.AVTransport do
  @moduledoc """
  Defines a “common” model for A/V transport control suitable for a UPnP generic user interface.
  """

  use MusicCast.UPnP.Service, type: "AVTransport:1"

  defmodule URIMetaData do
    @moduledoc false
    defstruct [:title, :artist, :album, :album_cover_url, :mimetype]
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
    ~s(<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:dc="http://purl.org/dc/elements/1.1/">
       <item id="f-0" parentID="0" restricted="0">
         <dc:title>#{meta.title}</dc:title>
         <upnp:album>#{meta.album}</upnp:album>
         <upnp:albumArtURI>#{meta.album_cover_url}</upnp:albumArtURI>
         <upnp:artist>#{meta.artist}</upnp:artist>
         <upnp:class>object.item.audioItem.musicTrack</upnp:class>
         <res protocolInfo="#{dlna_content_features(meta.mimetype)}">#{url}</res>
       </item>
       </DIDL-Lite>)
  end
end
