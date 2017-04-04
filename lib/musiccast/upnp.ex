defmodule MusicCast.UPnP do
  import SweetXml
  @moduledoc """
  Helper functions for working with UPnP services.
  """

  @doc """
  Calls an action on a UPNP service.
  """
  @spec call_action(String.t, String.t, String.t | Atom.t, Map.t) :: {:ok, term} | {:error, term}
  def call_action(url, service_type, action, params) do
    body = serialize(service_type, action, params)
    case HTTPoison.post(url, body, ["SOAPAction": "\"#{service_type}##{action}\""]) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status in 200..299 ->
        {:ok, xpath(body, ~x"//s:Envelope/s:Body/u:#{action}Response[xmlns:u=#{service_type}]")}
      {:ok, %HTTPoison.Response{body: body}} ->
        error = xpath(body, ~x"//s:Envelope/s:Body/s:Fault/detail/u:UPnPError",
          code: ~x"./u:errorCode/text()"i,
          desc: ~x"./u:errorDescription/text()"s)
        {:error, {:upnp_error, error.code, error.desc}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  #
  # Helpers
  #

  defp serialize(service_type, action, params) do
    service_type
    |> body_params(action, params)
    |> List.wrap
    |> envelope
    |> List.wrap
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten
    |> to_string
  end

  defp envelope(body) do
    {:"s:Envelope", ["s:encodingStyle": "http://schemas.xmlsoap.org/soap/encoding/", "xmlns:s": "http://schemas.xmlsoap.org/soap/envelope/"], body}
  end

  defp body_params(service_type, action, params) do
    {:"s:Body", [{:"u:#{action}", ["xmlns:u": service_type], Enum.map(params, &map_param/1)}]}
  end

  defp map_param({key, val}) do
    {:"#{key}", [[to_string(val)]]}
  end
end
