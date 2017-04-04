defmodule MusicCast.UPnP do
  import SweetXml
  @moduledoc """
  Helper functions for working with UPnP services.
  """

  @doc """
  Returns a map representing the UPnP service.
  """
  @spec describe(String.t) :: {:ok, term} | {:error, term}
  def describe(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, deserialize_desc(body)}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Calls an action on a UPnP service.
  """
  @spec call_action(String.t, String.t, String.t | Atom.t, Map.t) :: {:ok, term} | {:error, term}
  def call_action(url, service_type, action, params) do
    body = serialize_action(service_type, action, params)
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

  defp serialize_action(service_type, action, params) do
    service_type
    |> body_params(action, params)
    |> List.wrap
    |> envelope
    |> List.wrap
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten
    |> to_string
  end

  defp deserialize_desc(xml) do
    xpath(xml,
      ~x"//*",
      action_list: [
        ~x"./actionList/action"l,
        name: ~x"./name/text()"s,
        argument_list: [
          ~x"./argumentList/argument"l,
          name: ~x"./name/text()"s,
          direction: ~x"./direction/text()"s,
          related_state_variable: ~x"./relatedStateVariable/text()"s
        ]
      ],
      property_list: [
        ~x"./serviceStateTable/stateVariable"l,
        name: ~x"./name/text()"s,
        type: ~x"./dataType/text()"s
      ]
    )
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
