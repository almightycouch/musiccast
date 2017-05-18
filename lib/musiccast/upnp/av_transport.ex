defmodule MusicCast.UPnP.AVTransport do
  @moduledoc """
  Defines a “common” model for *UPnP A/V transport* control suitable for a UPnP generic user interface.
  """

  use MusicCast.UPnP.Service, type: "AVTransport:1"

  alias MusicCast.UPnP.URIMetaData

  def set_av_transport_uri(control_url, instance_id, current_uri, nil), do: super(control_url, instance_id, current_uri, "")
  def set_av_transport_uri(control_url, instance_id, current_uri, meta) when is_binary(meta), do: super(control_url, instance_id, current_uri, meta)
  def set_av_transport_uri(control_url, instance_id, current_uri, %URIMetaData{} = current_uri_meta_data) do
    super(control_url, instance_id, current_uri, URIMetaData.didl_lite([{current_uri, current_uri_meta_data}]))
  end

  def set_next_av_transport_uri(control_url, instance_id, next_uri, nil), do: super(control_url, instance_id, next_uri, "")
  def set_next_av_transport_uri(control_url, instance_id, next_uri, meta) when is_binary(meta), do: super(control_url, instance_id, next_uri, meta)
  def set_next_av_transport_uri(control_url, instance_id, next_uri, %URIMetaData{} = next_uri_meta_data) do
    super(control_url, instance_id, next_uri, URIMetaData.didl_lite([{next_uri, next_uri_meta_data}]))
  end
end
