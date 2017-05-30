defmodule MusicCast.UPnP.Service do
  @moduledoc """
  A module for working with UPnP compliant services.

  * It can automatically generate UPnP compliant clients from XML specifications.
  * It provides pub/sub cababilities to subscribe and forward UPnP event notifcations.


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

  @type subscription :: {String.t, Integer.t}

  @doc """
  Returns a map representing the UPnP service.
  """
  @spec describe(String.t) :: {:ok, Map.t} | {:error, term}
  def describe(service_url) do
    case HTTPoison.get(service_url) do
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
  def call_action(control_url, service_type, action, params) do
    headers = [
      "SOAPAction": "\"#{service_type}##{action}\""
    ]
    body = serialize_action(service_type, action, params)
    case HTTPoison.post(control_url, body, headers) do
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
  Returns a service event struct from the given XML payload.
  """
  @spec cast_event(Module.t, String.t) :: Map.t
  def cast_event(service, payload) do
    var = Map.new(service.__meta__)
    payload
    |> HtmlEntities.decode()
    |> xpath(~x"//e:property/LastChange/Event/InstanceID/*"l)
    |> Enum.map(fn props -> {to_string(xmlElement(props, :name)), xpath(props, ~x"./@val"s)} end)
    |> Enum.map(fn {key, val} -> {String.to_atom(Macro.underscore(key)), val} end)
    |> Enum.map(fn {key, val} -> {key, cast_variable(val, Map.get(var, key))} end)
    |> serialize_event(service)
  end

  @doc """
  Subscribes to a UPnP service.
  """
  @spec subscribe(String.t, String.t, Integer.t) :: {:ok, subscription} | {:error, term}
  def subscribe(event_url, callback_url_or_session_id, timeout \\ 300) do
    headers =
      if String.starts_with?(callback_url_or_session_id, "uuid:"),
        do: ["SID": callback_url_or_session_id],
      else: ["NT": "upnp:event", "CALLBACK": "<#{callback_url_or_session_id}>", "TIMEOUT": "Second-#{timeout}"]
    case HTTPoison.request(:subscribe, event_url, "", headers) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        %{"SID" => session_id, "TIMEOUT" => "Second-" <> timeout} = Map.new(headers)
        {:ok, {session_id, String.to_integer(timeout)}}
      {:ok, %HTTPoison.Response{status_code: 412}} ->
        {:error, :precondition_failed}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  Unsubscribes from a UPnP service.
  """
  @spec unsubscribe(String.t, String.t) :: :ok | {:error, term}
  def unsubscribe(event_url, session_id) do
    headers = ["SID": session_id]
    case HTTPoison.request(:unsubscribe, event_url, "", headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        :ok
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
    external_resource = quote do: @external_resource  unquote(path)
    urn = "urn:schemas-upnp-org:service:" <> type_spec
    service = deserialize_desc(File.stream!(path))
    props = serialize_props(service.property_list)
    items = Keyword.keys(props)
    struct = quote do
        defstruct unquote(items)
        @type t :: %__MODULE__{}
      end
    defvar =
      quote do
        def __meta__, do: unquote(props)
      end
    actions =
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
    [struct, external_resource, actions, defvar]
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

  defp serialize_props(props) do
    Enum.filter_map(props,
      fn %{name: name} -> !String.starts_with?(name, "A_ARG") end,
      fn %{name: name, type: type} -> {String.to_atom(Macro.underscore(name)), String.to_atom(type)} end)
  end

  defp serialize_event(props, MusicCast.UPnP.AVTransport = service) do
    props =
      props
      |> decode_didl(:current_track_meta_data)
      |> decode_didl(:next_track_meta_data)
      |> decode_didl(:av_transport_uri_meta_data)
      |> decode_didl(:next_av_transport_uri_meta_data)
    struct(service, props)
  end

  defp serialize_event(props, service) do
    struct(service, props)
  end

  defp decode_didl(props, key) do
    update_in(props, [key], fn item ->
      case MusicCast.UPnP.AVMusicTrack.didl_decode(item) do
        [item] -> item
         items -> items
      end
    end)
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

  defp cast_variable("OK", _type), do: :ok
  defp cast_variable("NOT_IMPLEMENTED", _type), do: :not_implemented
  defp cast_variable(val, type) when type in [:ui4, :i4], do: String.to_integer(val)
  defp cast_variable(val, _type), do: val

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
