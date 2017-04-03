defmodule MusicCast.SSDPClient do
  @moduledoc """
  A basic SSDP client module for discovery on the local network.
  """

  use GenServer

  import SweetXml

  @ssdp_st "urn:schemas-upnp-org:device:MediaRenderer:1"
  @ssdp_mx 2

  @multicast_addr {239, 255, 255, 250}
  @multicast_port 1900

  @doc """
  Starts a SSDP client as part of a supervision tree.
  """
  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], options)
  end

  @doc """
  Broadcasts a SSDP `M-SEARCH` request on the local network.
  """
  @spec discover() :: :ok
  def discover do
    GenServer.cast(__MODULE__, :discover)
  end

  #
  # Callbacks
  #

  def init([]) do
    udp_options = [
      :binary,
      add_membership: { @multicast_addr, {0, 0, 0, 0}},
      multicast_if: {0, 0, 0, 0},
      multicast_loop: false,
      multicast_ttl: 2,
      reuseaddr: true
    ]

    case :gen_udp.open(@multicast_port, udp_options) do
      {:ok, sock} ->
        {:ok, %{sock: sock, entities: %{}}}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_cast(:discover, state) do
    case :gen_udp.send(state.sock, @multicast_addr, @multicast_port, search_msg(@ssdp_st, @ssdp_mx)) do
      :ok ->
        {:noreply, state}
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:udp, _sock, addr, _port, packet}, %{entities: entities} = state) do
    entities =
      if ssdp_msg = parse_ssdp_packet(packet) do
        target = ssdp_msg[:st] || ssdp_msg[:nt]
        if target == @ssdp_st do
          Map.put_new_lazy(entities, addr, fn ->
            if info = request_device_info(ssdp_msg.location) do
              mount_device(addr, info.device)
            end
          end)
        end
      end || entities
    {:noreply, %{state | entities: entities}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{entities: entities} = state) do
    entities = Enum.reject(entities, &elem(&1, 1) == ref)
    {:noreply, %{state | entities: Map.new(entities)}}
  end

  #
  # Helpers
  #

  defp mount_device(addr, _device) do
    case MusicCast.Network.add_device(addr) do
      {:ok, pid} ->
        Process.monitor(pid)
      {:error, {:already_registered, pid}} ->
        Process.monitor(pid)
      {:error, _reason} ->
        nil
    end
  end

  defp request_device_info(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        body
        |> decode_device_info
        |> Map.put(:url, url)
      {:error, %HTTPoison.Error{}} ->
        nil
    end
  end

  defp search_msg(search_target, max_seconds) do
    ["M-SEARCH * HTTP/1.1\r\n",
     "Host: #{:inet_parse.ntoa(@multicast_addr)}:#{@multicast_port}\r\n",
     "MAN: \"ssdp:discover\"\r\n",
     "ST: #{search_target}\r\n",
     "MX: #{max_seconds}\r\n", "\r\n"]
  end

  defp atomize_string(str) do
    str
    |> String.downcase()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp parse_ssdp_packet(packet) do
    case packet do
      <<"HTTP/1.1 200 OK", body :: binary>> -> decode_ssdp_packet(body)
      <<"NOTIFY * HTTP/1.1", body :: binary>> -> decode_ssdp_packet(body)
      <<"M-SEARCH * HTTP/1.1", _body :: binary>> -> nil
    end
  end

  defp decode_ssdp_packet(packet) do
    packet
    |> String.split(["\r\n", "\n"])
    |> Enum.map(&String.split(&1, ":", parts: 2))
    |> Enum.filter_map(& length(&1) == 2, fn [key, val] -> {atomize_string(key), String.strip(val)} end)
    |> Enum.into(%{})
  end

  defp decode_device_info(xml_response) do
	xpath(xml_response,
      ~x"//root",
      version: [
          ~x"./specVersion",
          major: ~x"./major/text()",
          minor: ~x"./minor/text()",
      ],
      device: [
          ~x"./device",
          device_type: ~x"./deviceType/text()",
          friendly_name: ~x"./friendlyName/text()",
          manufacturer: ~x"./manufacturer/text()",
          manufacturer_url: ~x"./manufacturerURL/text()",
          model_description: ~x"./modelDescription/text()",
          model_name: ~x"./modelName/text()",
          model_number: ~x"./modelNumber/text()",
          model_url: ~x"./modelURL/text()",
          udn: ~x"./UDN/text()",
          presentation_url: ~x"./presentationURL/text()",
          icon_list: [
              ~x"./iconList/icon"l,
              mime_type: ~x"./mimetype/text()",
              height: ~x"./height/text()",
              width: ~x"./width/text()",
              depth: ~x"./depth/text()",
              url: ~x"./url/text()",
          ],
          service_list: [
              ~x"./serviceList/service"l,
              service_type: ~x"./serviceType/text()",
              service_id: ~x"./serviceId/text()",
              scpd_url: ~x"./SCPDURL/text()",
              control_url: ~x"./controlURL/text()",
              event_sub_url: ~x"./eventSubURL/text()",
          ]
      ]
    )
  end
end
