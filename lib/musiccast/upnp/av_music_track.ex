defmodule MusicCast.UPnP.AVMusicTrack do
  @moduledoc """
  Defines a struct representing meta informations for a playable *UPnP A/V transport* URL.
  """

  import SweetXml

  defstruct [{:id, 0}, :title, :artist, :album, :album_cover_url, {:duration, 0}, :mimetype]

  @type t :: %__MODULE__{
    id: Integer.t,
    title: String.t,
    artist: String.t,
    album: String.t,
    album_cover_url: String.t,
    duration: Integer.t,
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
        Enum.map(items, &encode_item/1),
      ~s(</DIDL-Lite>)])
  end

  @doc """
  Returns a list of items for the given DIDL-Lite XML.
  """
  @spec didl_decode(String.t) :: [didl_item]
  def didl_decode(xml) when xml in [nil, ""], do: []
  def didl_decode(xml) do
    xml
    |> String.replace(~r/&/, "&amp;")
    |> decode_item()
    |> Enum.map(&didl_item/1)
  end

  @doc """
  Returns the DLNA protocol info for the given audio `mimetype`.
  """
  @spec dlna_protocol_info(String.t) :: String.t
  def dlna_protocol_info(mimetype)
  def dlna_protocol_info("audio/mp4"), do: "http-get:*:audio/mp4:DLNA.ORG_PN=AAC_ISO_320"
  def dlna_protocol_info(mimetype) when is_binary(mimetype), do: "http-get:*:#{mimetype}"
  def dlna_protocol_info(nil), do: ""

  #
  # Helpers
  #

  defp didl_item(item) do
    item = Map.update!(item, :duration, &decode_duration/1)
    {proto, item} = Map.pop(item, :protocol)
    struct(__MODULE__, Map.put(item, :mimetype, extract_mimetype(proto)))
  end

  defp didl_fields(meta) do
    meta
    |> Map.from_struct()
    |> Map.drop([:id, :duration, :mimetype])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map(&didl_field/1)
  end

  defp didl_field({:title, title}), do: "<dc:title>#{title}</dc:title>"
  defp didl_field({:album, album}), do: "<upnp:album>#{album}</upnp:album>"
  defp didl_field({:album_cover_url, url}), do: "<upnp:albumArtURI>#{url}</upnp:albumArtURI>"
  defp didl_field({:artist, artist}), do: "<upnp:artist>#{HtmlEntities.encode(artist)}</upnp:artist>"
  defp didl_field(_), do: ""

  defp encode_item({url, meta}) do
    [~s(<item id="#{meta.id}" parentID="0" restricted="0">),
      ~s(<upnp:class>object.item.audioItem.musicTrack</upnp:class>),
      didl_fields(meta),
      ~s(<res protocolInfo="#{dlna_protocol_info(meta.mimetype)}" duration="#{encode_duration(meta.duration)}">#{url}</res>),
    ~s(</item>)]
  end

  defp decode_item(xml) do
    xpath(xml, ~x"//item"l,
     [id: ~x"./@id"i,
      title: ~x"./dc:title/text()"s,
      artist: ~x"./upnp:artist/text()"s,
      album: ~x"./upnp:album/text()"s,
      album_cover_url: ~x"./upnp:albumArtURI/text()"s,
      duration: ~x"./res/@duration"s,
      protocol: ~x"./res/@protocolInfo"s]
    )
  end

  defp encode_duration(duration) do
    hours = :io_lib.format("~1..0B", [div(duration, 3_600)])
    minutes = :io_lib.format("~2..0B", [div(duration, 60)])
    seconds = :io_lib.format("~2..0B", [Integer.mod(duration, 60)])
    "#{hours}:#{minutes}:#{seconds}"
  end

  defp decode_duration(str) do
    unless String.length(str) == 0 do
      [h, m, s] =
        str
        |> String.split(":")
        |> Enum.map(&String.to_integer/1)
      (h * 3_600) + (m * 60) + s
    end || 0
  end

  defp extract_mimetype(info) do
    info
    |> String.split(":")
    |> Enum.at(2)
  end
end

