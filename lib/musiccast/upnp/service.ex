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

  defstruct [:device, :url, :version]
  @type t :: %__MODULE__{
    device: %{
      device_type: String.t,
      device_type: String.t,
      friendly_name: String.t,
      manufacturer: String.t,
      manufacturer_url: String.t,
      model_description: String.t,
      model_name: String.t,
      model_number: String.t,
      model_url: String.t,
      udn: String.t,
      presentation_url: String.t,
      icon_list: %{
        width: Integer.t,
        height: Integer.t,
        depth: Integer.t,
        mime_type: String.t,
        url: String.t
      },
      service_list: %{
        service_type: String.t,
        service_id: String.t,
        scpd_url: String.t,
        control_url: String.t,
        event_sub_url: String.t
      }
    },
    url: String.t,
    version: %{
      major: Integer.t,
      minor: Integer.t,
    }
  }

  @doc """
  Calls an action on a UPnP service.
  """
  @spec call_action(String.t, String.t, String.t | Atom.t, Map.t) :: {:ok, term} | {:error, term}
  def call_action(control_url, service_type, action, params) do
    body = serialize_action(service_type, action, params)
    case HTTPoison.post(control_url, body, ["SOAPAction": "\"#{service_type}##{action}\""]) do
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

  @doc """
  Returns a map representing the UPnP service.
  """
  @spec describe(String.t) :: {:ok, term} | {:error, term}
  def describe(service_url) do
    case HTTPoison.get(service_url) do
      {:ok, %HTTPoison.Response{body: body}} ->
        {:ok, deserialize_desc(body)}
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
      sig_size = length(fun_args) + 1
      quote do
        def unquote(fun)(control_url, unquote_splicing(fun_args)) do
          args = unquote(fun_args)
          tags = unquote(Macro.escape(cmd_args["in"] || []))
                 |> Enum.with_index
                 |> Enum.map(fn {%{name: name}, i} -> {name, Enum.at(args, i)} end)
          case unquote(__MODULE__).call_action(control_url, unquote(urn), unquote(name), tags) do
            {:ok, response} ->
              query_path = Enum.map(unquote(Macro.escape(cmd_args["out"] || [])), &{String.to_atom(Macro.underscore(&1.name)), ~x"./#{&1.name}/text()"s})
              result_map = xmap(response, query_path)
              if map_size(result_map) == 0, do: :ok, else: {:ok, result_map}
            {:error, reason} ->
              {:error, reason}
          end
        end
        defoverridable [{unquote(fun), unquote(sig_size)}]
      end
    end
  end

  #
  # Helpers
  #

  defp serialize_xml(xmerl) do
    xmerl
    |> List.wrap()
    |> :xmerl.export_simple(:xmerl_xml)
    |> List.flatten()
    |> to_string()
  end

  defp serialize_action(service_type, action, params) do
    service_type
    |> body_params(action, params)
    |> envelope()
    |> serialize_xml()
  end

  defp envelope(body) do
    {:"s:Envelope", ["s:encodingStyle": "http://schemas.xmlsoap.org/soap/encoding/", "xmlns:s": "http://schemas.xmlsoap.org/soap/envelope/"], List.wrap(body)}
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
