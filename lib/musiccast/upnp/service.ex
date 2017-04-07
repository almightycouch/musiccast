defmodule MusicCast.UPnP.Service do
  @moduledoc """
  A module for working with UPnP A/V services.

  ## Example

      defmodule AVTransport do
        use MusicCast.UPnP.Service, type: "AVTransport:1"
      end

  By default, the service will be generated from the `priv/<av_transport_1.xml>` file of the current application
  but it can be configured to be any subdirectory of priv by specifying the `:priv` option.
  """

  import SweetXml

  defstruct action_list: [], property_list: []

  @doc """
  Returns a map representing the UPnP service.
  """
  @spec describe(String.t) :: {:ok, term} | {:error, term}
  def describe(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, struct(__MODULE__, deserialize_desc(body))}
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
      {:ok, %HTTPoison.Response{body: body, status_code: 500}} ->
        error = xpath(body, ~x"//s:Envelope/s:Body/s:Fault/detail/u:UPnPError",
          code: ~x"./u:errorCode/text()"i,
          desc: ~x"./u:errorDescription/text()"s)
        {:error, {:upnp_error, error.code, error.desc}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defmacro __using__(options) do
    type_spec = Keyword.fetch!(options, :type)
    file_name =
      type_spec
      |> String.replace(":", "_")
      |> Macro.underscore
      |> Kernel.<>(".xml")
    path = Path.join(:code.priv_dir(Keyword.get(options, :priv, :musiccast)), file_name)
    service = deserialize_desc(File.stream!(path))
    urn = "urn:schemas-upnp-org:service:" <> type_spec
    for %{name: name, argument_list: args} <- service.action_list do
      fun = String.to_atom(Macro.underscore(name))
      cmd_args = Enum.group_by(args, & &1.direction)
      fun_args = Enum.map(cmd_args["in"] || [], &Macro.var(String.to_atom(Macro.underscore(&1.name)), __MODULE__))
      quote do
        def unquote(fun)(url, unquote_splicing(fun_args)) do
          args = unquote(fun_args)
          tags = unquote(Macro.escape(cmd_args["in"] || []))
                 |> Enum.with_index
                 |> Enum.map(fn {%{name: name}, i} -> {name, Enum.at(args, i)} end)
          case unquote(__MODULE__).call_action(url, unquote(urn), unquote(name), tags) do
            {:ok, response} ->
              query_path = Enum.map(unquote(Macro.escape(cmd_args["out"] || [])), &{String.to_atom(Macro.underscore(&1.name)), ~x"./#{&1.name}/text()"s})
              result_map = xmap(response, query_path)
              if map_size(result_map) == 0, do: :ok, else: {:ok, result_map}
            {:error, reason} ->
              {:error, reason}
          end
        end
      end
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

  defp envelope(body) do
    {:"s:Envelope", ["s:encodingStyle": "http://schemas.xmlsoap.org/soap/encoding/", "xmlns:s": "http://schemas.xmlsoap.org/soap/envelope/"], body}
  end

  defp body_params(service_type, action, params) do
    {:"s:Body", [{:"u:#{action}", ["xmlns:u": service_type], Enum.map(params, &map_param/1)}]}
  end

  defp map_param({key, val}) do
    {:"#{key}", [[to_string(val)]]}
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
end
