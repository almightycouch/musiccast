defmodule MusicCast.UPnP.URIMetaData do
  @moduledoc """
  Defines a struct representing meta informations for a playable *UPnP A/V transport* URI.
  """

  defstruct [:title, {:duration, 0}, :artist, :album, :album_cover_url, :mimetype]

  @type t :: %__MODULE__{
    title: String.t,
    duration: Integer.t,
    artist: String.t,
    album: String.t,
    album_cover_url: String.t,
    mimetype: String.t,
  }

  @type didl_item :: {String.t, t}

  @doc """
  Returns a DIDL-Lite XML represention of the given `items`.
  """
  @spec didl_encode([didl_item]) :: String.t
  def didl_encode(items) do
    to_string([
      ~s(<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns:dc="http://purl.org/dc/elements/1.1/">),
        Enum.map(items, &didl_item/1),
      ~s(</DIDL-Lite>)])
  end

  @doc """
  Returns a list of items for the given DIDL-Lite XML.
  """
  @spec didl_decode(String.t) :: [didl_item]
  def didl_decode(_xml) do
    nil
  end

  defp didl_item({url, meta}) do
    [~s(<item id="f-0" parentID="0" restricted="0">),
      ~s(<upnp:class>object.item.audioItem.musicTrack</upnp:class>),
      didl_fields(meta),
      ~s(<res protocolInfo="#{dlna_protocol_info(meta.mimetype)}" duration="#{duration(meta.duration)}">#{url}</res>),
    ~s(</item>)]
  end

  @doc """
  Returns the DLNA protocol info for the given audio `mimetype`.
  """
  @spec dlna_protocol_info(String.t) :: String.t
  def dlna_protocol_info(mimetype)
  def dlna_protocol_info("audio/mp4"), do: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320;DLNA.ORG_FLAGS=9D300000000000000000000000000000"
  def dlna_protocol_info(mimetype) when is_binary(mimetype), do: "http-get:*:#{mimetype}"
  def dlna_protocol_info(nil), do: ""

  #
  # Helpers
  #

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
  defp didl_field(_), do: ""

  defp duration(duration) do
    hours = :io_lib.format("~2..0B", [div(duration, 3_600)])
    minutes = :io_lib.format("~2..0B", [div(duration, 60)])
    seconds = :io_lib.format("~2..0B", [Integer.mod(duration, 60)])
    "#{hours}:#{minutes}:#{seconds}"
  end
end

