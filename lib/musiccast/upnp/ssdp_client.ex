defmodule MusicCast.UPnP.SSDPClient do
  @moduledoc """
  A basic SSDP client module for UPnP discovery on the local network.

  In order to discover MusicCast enabled devices on the network,
  the SSDP client broadcasts a search request on the mulicast address `239.255.255.250`, port `1900`.

  Once the search request succeeds, MusicCast devices will announce themselves through the network
  and automatically start `MusicCast.Network.Entity` processes on the `MusicCast.Network`.
  """

  use GenServer

  import SweetXml

  @ssdp_st "urn:schemas-upnp-org:device:MediaRenderer:1"
  @ssdp_mx 2

  @multicast_addr {239, 255, 255, 250}
  @multicast_port 1900

  @auto_discover_timeout 2_000

  @doc """
  Starts a SSDP client as part of a supervision tree.
  """
  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(options \\ []) do
    options = Keyword.put(options, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], options)
  end

  @doc """
  Stops the SSDP client process.
  """
  @spec stop(pid, term, timeout) :: :ok
  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(pid, reason, timeout)
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
        Process.send_after(self(), {:"$gen_cast", :discover}, @auto_discover_timeout)
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
            if desc = request_desc(ssdp_msg.location) do
              mount_device(addr, desc)
            end
          end)
        end
      end || entities
    {:noreply, %{state | entities: entities}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{entities: entities} = state) do
    entities = Map.new(Enum.reject(entities, &elem(&1, 1) == ref))
    {:noreply, %{state | entities: entities}}
  end

  #
  # Helpers
  #

  defp mount_device(addr, desc) do
    case MusicCast.Network.add_device(addr, struct(MusicCast.UPnP.Service, desc)) do
      {:ok, pid} ->
        Process.monitor(pid)
      {:error, {:already_registered, pid}} ->
        Process.monitor(pid)
      {:error, _reason} ->
        nil
    end
  end

  defp request_desc(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        body
        |> decode_device_info()
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
          major: ~x"./major/text()"i,
          minor: ~x"./minor/text()"i,
      ],
      device: [
          ~x"./device",
          device_type: ~x"./deviceType/text()"s,
          friendly_name: ~x"./friendlyName/text()"s,
          manufacturer: ~x"./manufacturer/text()"s,
          manufacturer_url: ~x"./manufacturerURL/text()"s,
          model_description: ~x"./modelDescription/text()"s,
          model_name: ~x"./modelName/text()"s,
          model_number: ~x"./modelNumber/text()"s,
          model_url: ~x"./modelURL/text()"s,
          udn: ~x"./UDN/text()"s,
          presentation_url: ~x"./presentationURL/text()"s,
          icon_list: [
              ~x"./iconList/icon"l,
              mime_type: ~x"./mimetype/text()"s,
              height: ~x"./height/text()"i,
              width: ~x"./width/text()"i,
              depth: ~x"./depth/text()"i,
              url: ~x"./url/text()"s,
          ],
          service_list: [
              ~x"./serviceList/service"l,
              service_type: ~x"./serviceType/text()"s,
              service_id: ~x"./serviceId/text()"s,
              scpd_url: ~x"./SCPDURL/text()"s,
              control_url: ~x"./controlURL/text()"s,
              event_sub_url: ~x"./eventSubURL/text()"s,
          ]
      ]
    )
  end
end
