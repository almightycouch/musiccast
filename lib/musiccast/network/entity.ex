defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for managing MusicCast™ enabled devices.

  A network entity is automatically started when a MusicCast enabled device is
  discovered. See the `MusicCast.UPnP.SSDPClient` for implementation details. Once started,
  the entity process is available to the network registry via it MusicCast device ID.
  See `MusicCast.whereis/1` and `MusicCast.which_devices/1` for more details about the network registry.

  Each entity process keeps it state synchronized with the device it is paired with.
  This task is acomplished by the `MusicCast.Network.EventListener` process which forwards
  incoming YXC unicast messages to the affected entity processes.
  See `MusicCast.subscribe/1` and `MusicCast.unsubscribe/1` for more details.
  """

  use GenServer

  alias MusicCast.ExtendedControl, as: YXC
  alias MusicCast.UPnP.AVTransport

  defstruct host: nil,
            upnp: nil,
            device_id: nil,
            network_name: nil,
            available_inputs: [],
            status: nil,
            playback: nil

  @type ip_address :: {0..255, 0..255, 0..255, 0..255}

  @type device_id :: String.t
  @type upnp_desc :: Map.t

  @type lookup_key :: :host | :upnp | :device_id | :network_name | :available_inputs | :status | :playback
  @type lookup_keys :: [lookup_key] | lookup_key

  @doc """
  Starts an entity as part of a supervision tree.
  """
  @spec start_link(ip_address, upnp_desc, Keyword.t) :: GenServer.on_start
  def start_link(addr, upnp_desc, options \\ []) do
    GenServer.start_link(__MODULE__, {addr, upnp_desc}, options)
  end

  defdelegate stop(pid), to: GenServer

  @doc """
  Begins playback of the current track.
  """
  @spec playback_play(pid) :: :ok | {:error, term}
  def playback_play(pid) do
    GenServer.call(pid, {:extended_control, {:set_playback, :play}})
  end

  @doc """
  Pauses playback of the current track.
  """
  @spec playback_pause(pid) :: :ok | {:error, term}
  def playback_pause(pid) do
    GenServer.call(pid, {:extended_control, {:set_playback, :pause}})
  end

  @doc """
  Stops playback.
  """
  @spec playback_stop(pid) :: :ok | {:error, term}
  def playback_stop(pid) do
    GenServer.call(pid, {:extended_control, {:set_playback, :stop}})
  end

  @doc """
  Plays the previous track in the playback queue.
  """
  @spec playback_previous(pid) :: :ok | {:error, term}
  def playback_previous(pid) do
    GenServer.call(pid, {:extended_control, {:set_playback, :previous}})
  end

  @doc """
  Plays the next track in the playback queue.
  """
  @spec playback_next(pid) :: :ok | {:error, term}
  def playback_next(pid) do
    GenServer.call(pid, {:extended_control, {:set_playback, :next}})
  end

  @doc """
  Sets the UPnP A/V transport URL to the given `url`.
  """
  @spec upnp_set_av_transport_url(pid, String.t) :: :ok | {:error, term}
  def upnp_set_av_transport_url(pid, url) do
    GenServer.call(pid, {:upnp_av_transport, {:set_av_transport_uri, [url, []]}})
  end

  @doc """
  Begins playback of the current UPnP A/V transport URL.
  """
  @spec upnp_play(pid) :: :ok | {:error, term}
  def upnp_play(pid) do
    GenServer.call(pid, {:upnp_av_transport, {:play, 1}})
  end

  @doc """
  Pauses playback of the current UPnP A/V transport URL.
  """
  @spec upnp_pause(pid) :: :ok | {:error, term}
  def upnp_pause(pid) do
    GenServer.call(pid, {:upnp_av_transport, {:pause, []}})
  end

  @doc """
  Stops playback of the current UPnP A/V transport URL.
  """
  @spec upnp_stop(pid) :: :ok | {:error, term}
  def upnp_stop(pid) do
    GenServer.call(pid, {:upnp_av_transport, {:stop, []}})
  end

  @doc """
  Selects the given `input`.

  To get a list of available inputs for a specific device, pass `:available_inputs` to `__lookup__/2`.
  """
  @spec select_input(pid, Atom.t) :: :ok | {:error, term}
  def select_input(pid, input) do
    GenServer.call(pid, {:extended_control, {:set_input, input}})
  end

  @doc """
  Sets the volume to the given `volume`.
  """
  @spec set_volume(pid, Integer.t) :: :ok | {:error, term}
  def set_volume(pid, volume) when is_integer(pid) do
    GenServer.call(pid, {:extended_control, {:set_volume, volume}})
  end

  @doc """
  Increases the volume by `step`.
  """
  @spec increase_volume(pid, Integer.t) :: :ok | {:error, term}
  def increase_volume(pid, step \\ 10) when is_integer(step) do
    GenServer.call(pid, {:extended_control, {:set_volume, ["up", [step: step]]}})
  end

  @doc """
  Decreases the volume by `step`.
  """
  @spec decrease_volume(pid, Integer.t) :: :ok | {:error, term}
  def decrease_volume(pid, step \\ 10) when is_integer(step) do
    GenServer.call(pid, {:extended_control, {:set_volume, ["down", [step: step]]}})
  end

  @doc """
  Mutes the volume.
  """
  @spec mute(pid) :: :ok | {:error, term}
  def mute(pid) do
    GenServer.call(pid, {:extended_control, {:set_mute, true}})
  end

  @doc """
  Unmutes the volume.
  """
  @spec unmute(pid) :: :ok | {:error, term}
  def unmute(pid) do
    GenServer.call(pid, {:extended_control, {:set_mute, false}})
  end

  @doc """
  Toggles repeat settings.
  """
  @spec toggle_repeat(pid) :: :ok | {:error, term}
  def toggle_repeat(pid) do
    GenServer.call(pid, {:extended_control, {:toggle_repeat, []}})
  end

  @doc """
  Toggles repeat settings.
  """
  @spec toggle_shuffle(pid) :: :ok | {:error, term}
  def toggle_shuffle(pid) do
    GenServer.call(pid, {:extended_control, {:toggle_shuffle, []}})
  end

  @doc """
  Looks-up the value(s) for the given key(s).
  """
  @spec __lookup__(GenServer.server, lookup_keys) :: [term] | term
  def __lookup__(pid, keys \\ :all) do
    lookup_keys = Map.keys(Map.from_struct(%__MODULE__{}))
    case keys do
      :all ->
        GenServer.call(pid, {:lookup, :all})
      key when is_atom(key) ->
        unless key in lookup_keys, do: raise ArgumentError, message: "#{inspect key} is not a valid lookup key"
        GenServer.call(pid, {:lookup, key})
      keys when is_list(keys) ->
        if invalid_key = Enum.find(keys, & not &1 in lookup_keys), do: raise ArgumentError, message: "#{inspect invalid_key} is not a valid lookup key"
        GenServer.call(pid, {:lookup, keys})
    end
  end

  #
  # Callbacks
  #

  def init({addr, upnp_desc}) do
    with host <- to_string(:inet_parse.ntoa(addr)),
         {:ok, %{"device_id" => device_id}} <- YXC.get_device_info(host, headers: YXC.subscription_headers()),
         {:ok, %{"network_name" => network_name}} <- YXC.get_network_status(host),
         {:ok, %{"system" => system}} <- YXC.get_features(host),
         {:ok, upnp} <- parse_upnp_desc(upnp_desc),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, _} <- register_device(device_id, addr) do
      announce_device(%__MODULE__{
        host: host,
        upnp: upnp.device,
        device_id: device_id,
        network_name: network_name,
        available_inputs: Enum.map(system["input_list"], & &1["id"]),
        status: serialize_status(status),
        playback: serialize_playback(playback, host)})
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:lookup, :all}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:lookup, keys}, _from, state) do
    attrs = for key <- List.wrap(keys), Map.has_key?(state, key), do: Map.fetch!(state, key)
    if is_list(keys),
      do: {:reply, attrs, state},
    else: {:reply, List.first(attrs), state}
  end

  def handle_call({:extended_control, {fun, args}}, _from, state) do
    case apply(YXC, fun, [state.host|List.wrap(args)]) do
      {:ok, _resp} ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:upnp_av_transport, {fun, args}}, _from, state) do
    service = Enum.find(state.upnp.service_list, nil, & &1.service_id == "urn:upnp-org:serviceId:AVTransport")
    {:reply, apply(AVTransport, fun, [service.control_url, 0] ++ List.wrap(args)), state}
  end

  def handle_info(:timeout, state) do
    case YXC.get_status(state.host, headers: YXC.subscription_headers()) do
      {:ok, status} ->
        Process.send_after(self(), :timeout, YXC.subscription_timeout())
        {:noreply, struct(state, status: status)}
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:unicast_event, payload}, state) do
    state =
      Enum.reduce(payload, state, fn {_, event}, state ->
        new_state = update_state(state, atomize_map(event))
        event_map = diff_state(Map.from_struct(state), Map.from_struct(new_state))
        unless map_size(event_map) == 0, do: broadcast_state_update(state.device_id, event_map)
        new_state
      end)
    {:noreply, state}
  end

  #
  # Helpers
  #

  defp announce_device(%__MODULE__{} = state) do
    Registry.dispatch(MusicCast.PubSub, "network", fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:extended_control, :network, state})
    end)
    {:ok, state, YXC.subscription_timeout()}
  end

  defp broadcast_state_update(device_id, event) do
    Registry.dispatch(MusicCast.PubSub, device_id, fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:extended_control, device_id, event})
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
  defp update_state(state, event), do: update_in(state.playback, &Map.merge(&1, event))

  defp update_playback_state(state) do
    case YXC.get_playback_info(state.host) do
      {:ok, playback} -> struct(state, playback: serialize_playback(playback, state.host))
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

  defp serialize_playback(playback, host) do
    playback
    |> atomize_map
    |> update_in([:albumart_url], &to_string(%URI{scheme: "http", host: host, path: &1}))
  end

  defp serialize_status(status) do
    atomize_map(status)
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
