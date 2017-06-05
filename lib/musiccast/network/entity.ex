defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for managing MusicCast™ enabled devices.

  A network entity is automatically started when a MusicCast enabled device is
  discovered. See the `MusicCast.UPnP.SSDPClient` for implementation details. Once started,
  the entity process is available to the network registry via it MusicCast device ID:

      iex> pid = MusicCast.whereis("00A0DEDCF73E")
      #PID<0.200.0>

  ## Synchronization

  Each entity process keeps it state synchronized with the device it is paired with.
  This task is acomplished by the `MusicCast.Network.EventDispatcher` process which forwards
  incoming YXC unicast messages to the affected entity processes.

  In order to receive UPnP A/V notification from MusicCast™ devices via UPnP A/V,
  you must forward the `MusicCast.UPnP.Plug.EventDispatcher` plug in your HTTP stack and configure your application accordingly.

  ## YXC & UPnP

  Extended Control or "YXC" is Yamaha’s communication protocol sent over Ethernet and Wi-Fi to
  control MusicCast™ devices. Each entity provides a set of functions for interacting with a device.

  See `MusicCast.ExtendedControl` for more details.

  On top of the commands provided by YXC, entities support the *UPnP A/V Transport* protocol. Functions such as `playback_load/3` and
  `playback_load_queue/2` provide a way to load streamable content via an URL.

  Gapless playback can be achieved with a combination of `playback_load/3` and `playback_load_next/3`.
  The latter basically tells the rendering devices which source to play next.

  To play multiple items, consider using `playback_load_queue/2`, it handles "previous" and "next" commands automatically,
  ensures gapless playback and supports "repeat" and "shuffle" modes.

  See `MusicCast.UPnP.AVTransport` for more details.
  """

  use GenServer

  alias MusicCast.ExtendedControl, as: YXC
  alias MusicCast.UPnP.{AVTransport, Service, AVMusicTrack}

  require Logger

  defstruct [{:available_inputs, []},
              :device_id,
              :host,
              :network_name,
              :status,
              :playback,
             {:playback_queue, %{media_url: nil, items: []}},
              :upnp,
              :upnp_service,
              :upnp_session_id]

  @type ip_address :: {0..255, 0..255, 0..255, 0..255}

  @type lookup_key ::
    :available_inputs |
    :device_id |
    :host |
    :network_name |
    :playback |
    :playback_queue |
    :status |
    :upnp |
    :upnp_service |
    :upnp_session_id

  @type lookup_query :: :all | [lookup_key] | lookup_key

  @type playback :: %{
    album: String.t,
    albumart_url: String.t,
    artist: String.t,
    input: String.t,
    play_time: Integer.t,
    playback: String.t,
    repeat: String.t,
    shuffle: String.t,
    total_time: Integer.t,
    track: String.t
  }

  @type status :: %{
    balance: Integer.t,
    bass_extension: boolean,
    direct: boolean,
    disable_flags: Integer.t,
    distribution_enable: boolean,
    enhancer: boolean,
    equalizer: %{high: Integer.t, low: Integer.t, mid: Integer.t, mode: String.t},
    input: String.t,
    link_audio_delay: String.t,
    link_control: String.t,
    max_volume: Integer.t,
    mute: boolean,
    power: String.t,
    sleep: Integer.t,
    subwoofer_volume: Integer.t,
    volume: Integer.t
  }

  @type t :: %__MODULE__ {
    available_inputs: [String.t],
    device_id: String.t,
    host: String.t,
    network_name: String.t,
    playback: playback,
    playback_queue: %{media_url: String.t, items: [AVMusicTrack.didl_item]},
    status: status,
    upnp: AVTransport.t,
    upnp_service: Service.t,
    upnp_session_id: String.t
  }

  @doc """
  Starts an entity as part of a supervision tree.
  """
  @spec start_link(ip_address, MusicCast.UPnP.Service.t, Keyword.t) :: GenServer.on_start
  def start_link(addr, upnp_desc, options \\ []) do
    GenServer.start_link(__MODULE__, {addr, upnp_desc}, options)
  end

  @doc """
  Stops the entity process.
  """
  @spec stop(pid, term, timeout) :: :ok
  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenServer.stop(pid, reason, timeout)
  end

  @doc """
  Begins playback of the current track.
  """
  @spec playback_play(pid) :: :ok | {:error, term}
  def playback_play(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_playback, :play}})
  end

  @doc """
  Loads the given list of `items` and immediately begins playback.

  All given `items` must conform to `t:MusicCast.UPnP.AVMusicTrack.didl_item/0`.
  """
  @spec playback_load_queue(pid, [Enum.t]) :: :ok | {:error, term}
  def playback_load_queue(pid, items) do
    didl_items = Enum.map(items, fn {url, meta} -> {url, struct(AVMusicTrack, meta)} end)
    GenServer.call(pid, {:upnp_load_queue, didl_items})
  end

  @doc """
  Loads the given URL and immediately begins playback.

  If given, `meta` must conform to `t:MusicCast.UPnP.AVMusicTrack.t/0`.
  """
  @spec playback_load(pid, String.t, Enum.t) :: :ok | {:error, term}
  def playback_load(pid, url, meta \\ nil) do
    didl_meta = if meta, do: struct(AVMusicTrack, meta)
    GenServer.call(pid, {:upnp_load, url, didl_meta})
  end

  @doc """
  Sets the next URL to load for gapless playback.

  If given, `meta` must conform to `t:MusicCast.UPnP.AVMusicTrack.t/0`.
  """
  @spec playback_load_next(pid, String.t, Enum.t) :: :ok | {:error, term}
  def playback_load_next(pid, url, meta \\ nil) do
    didl_meta = if meta, do: struct(AVMusicTrack, meta)
    GenServer.call(pid, {:upnp_load_next, url, didl_meta})
  end

  @doc """
  Pauses playback of the current track.
  """
  @spec playback_pause(pid) :: :ok | {:error, term}
  def playback_pause(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_playback, :pause}})
  end

  @doc """
  Stops playback.
  """
  @spec playback_stop(pid) :: :ok | {:error, term}
  def playback_stop(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_playback, :stop}})
  end

  @doc """
  Plays the previous track in the playback queue.
  """
  @spec playback_previous(pid) :: :ok | {:error, term}
  def playback_previous(pid) do
    GenServer.call(pid, :load_previous)
  end

  @doc """
  Plays the next track in the playback queue.
  """
  @spec playback_next(pid) :: :ok | {:error, term}
  def playback_next(pid) do
    GenServer.call(pid, :load_next)
  end

  @doc """
  Sets the power status to "on" or "standby".
  """
  @spec set_power(pid, String.t) :: :ok | {:error, term}
  def set_power(pid, power) do
    GenServer.call(pid, {:extended_control_action, {:set_power, power}})
  end

  @doc """
  Selects the given `input`.

  To get a list of available inputs from a specific device, see `__lookup__/2`.
  """
  @spec set_input(pid, String.t) :: :ok | {:error, term}
  def set_input(pid, input) do
    GenServer.call(pid, {:extended_control_action, {:set_input, input}})
  end

  @doc """
  Sets the volume to the given `volume`.
  """
  @spec set_volume(pid, Integer.t) :: :ok | {:error, term}
  def set_volume(pid, volume) when is_integer(volume) do
    GenServer.call(pid, {:extended_control_action, {:set_volume, volume}})
  end

  @doc """
  Increases the volume by `step`.
  """
  @spec increase_volume(pid, Integer.t) :: :ok | {:error, term}
  def increase_volume(pid, step \\ 10) when is_integer(step) do
    GenServer.call(pid, {:extended_control_action, {:set_volume, ["up", [step: step]]}})
  end

  @doc """
  Decreases the volume by `step`.
  """
  @spec decrease_volume(pid, Integer.t) :: :ok | {:error, term}
  def decrease_volume(pid, step \\ 10) when is_integer(step) do
    GenServer.call(pid, {:extended_control_action, {:set_volume, ["down", [step: step]]}})
  end

  @doc """
  Mutes the volume.
  """
  @spec mute(pid) :: :ok | {:error, term}
  def mute(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_mute, true}})
  end

  @doc """
  Unmutes the volume.
  """
  @spec unmute(pid) :: :ok | {:error, term}
  def unmute(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_mute, false}})
  end

  @doc """
  Toggles playback state from "play" to "pause" and vice versa.
  """
  @spec toggle_play_pause(pid) :: :ok | {:error, term}
  def toggle_play_pause(pid) do
    GenServer.call(pid, {:extended_control_action, {:set_playback, :play_pause}})
  end

  @doc """
  Toggles repeat settings.
  """
  @spec toggle_repeat(pid) :: :ok | {:error, term}
  def toggle_repeat(pid) do
    GenServer.call(pid, {:extended_control_action, {:toggle_repeat, []}})
  end

  @doc """
  Toggles repeat settings.
  """
  @spec toggle_shuffle(pid) :: :ok | {:error, term}
  def toggle_shuffle(pid) do
    GenServer.call(pid, {:extended_control_action, {:toggle_shuffle, []}})
  end

  @doc """
  Returns the state value(s) for the given lookup key(s).

  If you pass `:all`, this function will return the full state of the entity.

      iex> MusicCast.Network.Entity.__lookup__(pid, :all)
      %MusicCast.Network.Entity{...}

  If you prefer to query a subset of the entity's state, you can pass any number of `t:lookup_key/0`:

      iex> MusicCast.Network.Entity.__lookup__(pid, [:host, :network_name])
      ["192.168.0.63", "Schlafzimmer"]
  """
  @spec __lookup__(pid, lookup_query) :: any
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
         {:ok, upnp_desc} <- serialize_upnp_desc(upnp_desc),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, session_id} <- upnp_subscribe(upnp_desc),
         {:ok, _} <- register_device(device_id, addr) do
      announce_device(%__MODULE__{
        available_inputs: serialize_input_list(system["input_list"]),
        device_id: device_id,
        host: host,
        network_name: network_name,
        status: serialize_status(status),
        playback: serialize_playback(playback, host),
        upnp_service: upnp_desc,
        upnp_session_id: session_id})
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:lookup, :all}, _from, state) do
    {:reply, materialize(state), state}
  end

  def handle_call({:lookup, keys}, _from, state) do
    materialized_state = materialize(state)
    attrs = for key <- List.wrap(keys), Map.has_key?(materialized_state, key), do: Map.fetch!(materialized_state, key)
    if is_list(keys),
      do: {:reply, attrs, state},
    else: {:reply, List.first(attrs), state}
  end

  def handle_call(:load_previous, from, state) do
    items = state.playback_queue.items
    media = state.playback_queue.media_url
    cond do
      Enum.empty?(items) ->
        handle_call({:extended_control_action, {:set_playback, :previous}}, from, state)
      previous = queue_previous(items, media, state) ->
        {url, meta} = previous
        handle_call({:upnp_load, url, meta}, from, state)
      true ->
        {:reply, {:error, :wtf}, state}
    end
  end


  def handle_call(:load_next, from, state) do
    items = state.playback_queue.items
    media = state.playback_queue.media_url
    cond do
      Enum.empty?(items) ->
        handle_call({:extended_control_action, {:set_playback, :next}}, from, state)
      next = queue_next(items, media, state) ->
        {url, meta} = next
        handle_call({:upnp_load, url, meta}, from, state)
      true ->
        {:reply, {:error, :wtf}, state}
    end
  end

  def handle_call({:extended_control_action, {fun, args}}, _from, state) do
    case apply(YXC, fun, [state.host|List.wrap(args)]) do
      {:ok, _resp} ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:upnp_load_queue, items}, from, state) do
    new_state = update_state(state, put_in(state.playback_queue.items, items))
      if item = List.first(items) do
        {url, meta} = item
        handle_call({:upnp_load, url, meta}, from, new_state)
      else
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:upnp_load, url, meta}, _from, state) do
    service = av_transport_service(state.upnp_service.device)
    with :ok <- AVTransport.stop(service.control_url, 0),
         :ok <- AVTransport.set_av_transport_uri(service.control_url, 0, url, meta),
         :ok <- AVTransport.play(service.control_url, 0, 1) do
      broadcast_state_update(state.device_id, %{playback_queue: %{media_url: nil}})
      {:reply, :ok, put_in(state.playback_queue.media_url, nil)}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:upnp_load_next, url, meta}, _from, state) do
    service = av_transport_service(state.upnp_service.device)
    case AVTransport.set_next_av_transport_uri(service.control_url, 0, url, meta) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:upnp_stop, _from, state) do
    service = av_transport_service(state.upnp_service.device)
    case AVTransport.stop(service.control_url, 0) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_info({:subscription_timeout, :extended_control = target}, state) do
    case YXC.get_status(state.host, headers: YXC.subscription_headers()) do
      {:ok, status} ->
        renew_subscription(target, YXC.subscription_timeout())
        {:noreply, struct(state, status: status)}
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:subscription_timeout, {:upnp, session_id}}, state) do
    service = av_transport_service(state.upnp_service.device)
    case Service.subscribe(service.event_sub_url, session_id) do
      {:ok, {^session_id, timeout}} ->
        renew_subscription({:upnp, session_id}, timeout)
        {:noreply, state}
      {:ok, {new_session_id, timeout}} ->
        renew_subscription({:upnp, new_session_id}, timeout)
        broadcast_state_update(state.device_id, %{upnp_session_id: new_session_id})
        {:noreply, put_in(state.upnp_session_id, new_session_id)}
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  def handle_info({:extended_control_event, payload}, state) do
    state =
      Enum.reduce(payload, state, fn {_, event}, state ->
        update_state(state, update_state(state, atomize_map(event)))
      end)
    {:noreply, state}
  end

  def handle_info({:upnp_event, payload}, state) do
    new_state = put_in(state.upnp, payload)
    new_state =
      state
      |> diff_state(new_state)
      |> get_in([:upnp, :av_transport_uri])
      |> sync_next(new_state)
    {:noreply, update_state(state, new_state)}
  end

  #
  # Helpers
  #

  defp announce_device(%__MODULE__{} = state) do
    renew_subscription(:extended_control, YXC.subscription_timeout())
    Registry.dispatch(MusicCast.PubSub, "network", fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:musiccast, :online, state})
    end)
    {:ok, state}
  end

  defp broadcast_state_update(device_id, event) do
    Registry.dispatch(MusicCast.PubSub, device_id, fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:musiccast, :update, device_id, event})
    end)
  end

  defp register_device(device_id, addr) do
    Registry.register(MusicCast.Registry, device_id, addr)
  end

  defp sync_next(nil, state), do: state
  defp sync_next(media_url, state) do
    state = put_in(state.playback_queue.media_url, media_url)
    items = state.playback_queue.items
    if next = queue_next(items, media_url, state) do
      {url, meta} = next
      handle_call({:upnp_load_next, url, meta}, {self(), make_ref()},  state)
    end
    state
  end

  defp renew_subscription(target, timeout) do
    Process.send_after(self(), {:subscription_timeout, target}, max(0, timeout - 3) * 1_000)
  end

  defp upnp_subscribe(upnp_desc) do
    if callback_url = Application.get_env(:musiccast, :upnp_callback_url) do
      service = av_transport_service(upnp_desc.device)
      case Service.subscribe(service.event_sub_url, callback_url) do
        {:ok, {session_id, timeout}} ->
          renew_subscription({:upnp, session_id}, timeout)
          {:ok, session_id}
        {:error, reason} ->
          {:error, reason}
      end
    end || {:ok, nil}
  end

  defp queue_get(items, media_url, state, fun) do
    cond do
      Enum.empty?(items) ->
        nil
      state.playback.shuffle == "on" ->
        Enum.random(items)
      index = Enum.find_index(items, fn {url, _meta} -> url == media_url end) ->
        Enum.at(items, fun.(index), List.last(items))
      true -> nil
    end
  end

  defp queue_previous(items, media_url, state), do: queue_get(items, media_url, state, &(&1 - 1))
  defp queue_next(items, media_url, state), do: queue_get(items, media_url, state, &(&1 + 1))

  defp update_state(%__MODULE__{} = state, %__MODULE__{} = new_state) do
    event_map = diff_state(Map.from_struct(state), Map.from_struct(new_state))
    unless map_size(event_map) == 0, do: broadcast_state_update(state.device_id, event_map)
    new_state
  end

  defp update_state(state, %{status_updated: true} = event) do
    state
    |> update_state(Map.drop(event, [:status_updated]))
    |> update_status_state()
  end

  defp update_state(state, %{play_info_updated: true} = event) do
    state
    |> update_state(Map.drop(event, [:play_info_updated]))
    |> update_playback_state()
  end

  defp update_state(state, %{play_queue: _queue} = event) do
    update_state(state, Map.drop(event, [:play_queue]))
  end

  defp update_state(state, %{signal_info_updated: true} = event) do
    update_state(state, Map.drop(event, [:signal_info_updated]))
  end

  defp update_state(state, %{recent_info_updated: true} = event) do
    update_state(state, Map.drop(event, [:recent_info_updated]))
  end

  defp update_state(state, event) when is_map(event) do
    if map_size(event) > 0 do
      state_map =
        state
        |> Map.from_struct()
        |> update_in([:status], &apply_update(&1, event))
        |> update_in([:playback], &apply_update(&1, event))
      struct(__MODULE__, state_map)
    end || state
  end

  defp update_state(state, nil), do: state

  defp apply_update(state, event) do
    Enum.reduce(event, state, fn {k, v}, state ->
      if Map.has_key?(state, k) do
        unless is_map(v),
          do: put_in(state, [k], v),
        else: update_in(state, [k], &apply_update(&1, v))
      end || state
    end)
  end

  defp update_status_state(state) do
    case YXC.get_status(state.host) do
      {:ok, status} -> struct(state, status: serialize_status(status))
      {:error, _reason} -> state
    end
  end

  defp update_playback_state(state) do
    case YXC.get_playback_info(state.host) do
      {:ok, playback} -> struct(state, playback: serialize_playback(playback, state.host))
      {:error, _reason} -> state
    end
  end

  defp diff_state(old, new) when is_map(old) and is_map(new) do
    old = unstruct(old)
    new = unstruct(new)
    Enum.reduce(new, Map.new(), &diff_value(&1, old, &2) || &2)
  end

  defp diff_state(_old, new) when is_map(new), do: unstruct(new)
  defp diff_state(_old, new), do: new

  defp diff_value({k, v}, old, acc) when is_map(old) do
    {n, o} =
      if is_list(v) and Enum.all?(v, &(is_tuple(&1) && tuple_size(&1) == 2)),
        do: {unstruct(v), unstruct(old[k])},
      else: {v, old[k]}
    unless n == o do
      unless is_map(v),
        do: put_in(acc, [k], n),
      else: put_in(acc, [k], diff_state(o, n))
    end
  end

  defp unstruct(struct) when is_list(struct), do: unstruct_deep(struct)
  defp unstruct(struct) when is_map(struct) do
    unstruct_deep(
      if Map.has_key?(struct, :__struct__), do: Map.from_struct(struct), else: struct
    )
  end

  defp unstruct_deep(struct) do
    Enum.into(struct, %{}, fn
      {k, v} when is_map(v) -> {k, unstruct(v)}
      {k, v} -> {k, v}
    end)
  end

  defp atomize_map(map) do
    Enum.into(map, %{}, fn
      {key, val} when is_binary(key) and is_map(val) ->
        {String.to_atom(key), atomize_map(val)}
      {key, val} when is_binary(key) ->
        {String.to_atom(key), val}
      {key, val} when is_map(val) ->
        {key, atomize_map(val)}
      {key, val} ->
        {key, val}
    end)
  end

  defp serialize_playback(playback, host) do
    update_in(atomize_map(playback), [:albumart_url], fn path ->
      unless path == "", do: to_string(%URI{scheme: "http", host: host, path: path})
    end)
  end

  defp serialize_status(status) do
    atomize_map(status)
  end

  defp serialize_input_list(input_list) do
    Enum.map(input_list, & &1["id"])
  end

  defp serialize_upnp_desc(upnp_desc) do
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

  defp av_transport_service(device) do
    Enum.find(device.service_list, nil, & &1.service_id == "urn:upnp-org:serviceId:AVTransport")
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

  defp materialize(state) do
    update_in(state.playback_queue.items, &Enum.into(&1, %{}))
  end
end
