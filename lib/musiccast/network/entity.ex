defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for managing MusicCast™ enabled devices.

  A network entity is automatically started when a MusicCast enabled device is
  discovered. See the `MusicCast.UPnP.SSDPClient` for implementation details. Once started,
  the entity process is available to the network registry via it MusicCast device ID.
  See `MusicCast.whereis/1` and `MusicCast.which_devices/1` for more details about the network registry.

      iex> {pid, host} = MusicCast.whereis("ABCDEF01")
      {pid, {192, 168, 0, 63}}

  Each entity process keeps it state synchronized with the device it is paired with.
  This task is acomplished by the `MusicCast.Network.EventListener` process which forwards
  incoming YXC unicast messages to the affected entity processes.
  See `MusicCast.subscribe/1` and `MusicCast.unsubscribe/1` for more details.

  ## Yamaha Extended Control (YXC)

  As described previously, an entity automatically keeps it state synchronized to the device it is connected to.
  In order to fetch the current state of an entity, use the `__lookup__/2` function:

      iex> {pid, host} = MusicCast.whereis("ABCDEF01")
      {pid, {192, 168, 0, 63}}
      iex> MusicCast.Network.Entity.__lookup__(pid, :network_name)
      "Wohnzimmer"
      iex> MusicCast.Network.Entity.__lookup__(pid, :status)
      %{}

  See `t:lookup_keys/0` for a list of available lookup keys.
  """

  use GenServer

  alias MusicCast.ExtendedControl, as: YXC

  defstruct host: nil,
            upnp: nil,
            device_id: nil,
            network_name: nil,
            status: nil,
            playback: nil

  @type ip_address :: {0..255, 0..255, 0..255, 0..255}

  @type device_id :: String.t
  @type upnp_desc :: Map.t

  @type lookup_key :: :host | :upnp | :device_id | :network_name | :status | :playback
  @type lookup_keys :: [lookup_key] | lookup_key

  @doc """
  Starts an entity as part of a supervision tree.
  """
  @spec start_link(ip_address, upnp_desc, Keyword.t) :: GenServer.on_start
  def start_link(addr, upnp_desc, options \\ []) do
    GenServer.start_link(__MODULE__, {addr, upnp_desc}, options)
  end

  @doc """
  Looks-up the value(s) for the given key(s).
  """
  @spec __lookup__(GenServer.server, lookup_keys) :: [term] | term
  def __lookup__(pid, keys) do
    GenServer.call(pid, {:lookup, keys})
  end


  #
  # Callbacks
  #

  def init({addr, upnp_desc}) do
    headers = [
      {"X-AppName", "MusicCast/1.50"},
      {"X-AppPort", 41100}
    ]
    with host <- to_string(:inet_parse.ntoa(addr)),
         {:ok, %{"device_id" => device_id}} <- YXC.get_device_info(host, headers: headers),
         {:ok, %{"network_name" => network_name}} <- YXC.get_network_status(host),
         {:ok, upnp} <- parse_upnp_desc(upnp_desc),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, _} <- register_device(device_id, addr) do
      status = atomize_map(status)
      playback = atomize_map(playback)
      announce_device(device_id, host, network_name, status, playback)
      {:ok, %__MODULE__{host: host,
                        upnp: upnp,
                        device_id: device_id,
                        network_name: network_name,
                        status: status,
                        playback: playback}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:lookup, keys}, _from, state) do
    attrs = for key <- List.wrap(keys), Map.has_key?(state, key), do: Map.fetch!(state, key)
    if is_list(keys),
      do: {:reply, attrs, state},
    else: {:reply, List.first(attrs), state}
  end

  def handle_info({:unicast_event, payload}, state) do
    state =
      Enum.reduce(payload, state, fn {_, event}, state ->
        new_state = update_state(state, atomize_map(event))
        event_map = diff_state(Map.from_struct(state), Map.from_struct(new_state))
        unless map_size(event_map) == 0, do: broadcast_event(state.device_id, :update, event_map)
        new_state
      end)
    {:noreply, state}
  end

  #
  # Helpers
  #

  defp announce_device(device_id, host, network_name, status, playback) do
    state = %{host: host, network_name: network_name, status: status, playback: playback}
    Registry.dispatch(MusicCast.PubSub, "network", fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:extended_control, :online, device_id, state})
    end)
  end

  defp broadcast_event(device_id, event_type, event) do
    Registry.dispatch(MusicCast.PubSub, device_id, fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:extended_control, event_type, device_id, event})
    end)
  end

  defp register_device(device_id, addr) do
    Registry.register(MusicCast.Registry, device_id, addr)
  end

  defp update_state(state, %{status_updated: true} = event) do
    update_state(state, Map.drop(event, [:status_updated]))
  end

  defp update_state(state, %{signal_info_updated: true} = event) do
    update_state(state, Map.drop(event, [:signal_info_updated]))
  end

  defp update_state(state, %{play_info_updated: true}) do
    update_playback_state(state)
  end

  defp update_state(state, nil),   do: state
  defp update_state(state, event), do: update_in(state.status, &Map.merge(&1, event))

  defp update_playback_state(state) do
    case YXC.get_playback_info(state.host) do
      {:ok, playback} -> %{state | playback: playback}
      {:error, _reason} -> state
    end
  end

  defp diff_state(old, new) when is_map(old) and is_map(new) do
    Enum.reduce(new, Map.new(), &diff_value(&1, old, &2) || &2)
  end

  defp diff_value({k, v}, old, acc) when is_map(old) do
    unless v == old[k] do
      unless is_map(v),
        do: put_in(acc, [k], v),
      else: put_in(acc, [k], diff_state(old[k], v))
    end
  end

  defp atomize_map(map) do
    Enum.into(map, %{}, fn
      {key, val} when is_map(val) ->
        {String.to_atom(key), atomize_map(val)}
      {key, val} ->
        {String.to_atom(key), val}
    end)
  end

  defp parse_upnp_desc(upnp_desc) do
    try do
      base_url =
        upnp_desc
        |> Map.fetch!(:url)
        |> URI.parse
        |> struct!(path: "")
        |> URI.to_string
      {:ok, update_in(upnp_desc.device, &prefix_upnp_device_urls(&1, base_url))}
    rescue
      e -> {:error, e.message}
    end
  end

  defp prefix_upnp_device_urls(%{icon_list: icon_list, service_list: service_list} = device, base_url) do
    device
    |> put_in([:icon_list], prefix_upnp_icons_url(icon_list, base_url))
    |> put_in([:service_list], prefix_upnp_services_urls(service_list, base_url))
  end

  defp prefix_upnp_icons_url(icon_list, base_url) do
    Enum.map(icon_list, fn icon ->
      update_in(icon.url, &Kernel.<>(base_url, &1))
    end)
  end

  defp prefix_upnp_services_urls(service_list, base_url) do
    Enum.map(service_list, fn service ->
      service
      |> update_in([:control_url], &Kernel.<>(base_url, &1))
      |> update_in([:event_sub_url], &Kernel.<>(base_url, &1))
      |> update_in([:scpd_url], &Kernel.<>(base_url, &1))
    end)
  end
end
