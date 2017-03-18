defmodule MusicCast.Network.Entity do
  @moduledoc """
  A module for managing MusicCast enabled devices.
  """

  use GenServer

  require Logger

  alias MusicCast.ExtendedControl, as: YXC

  defstruct host: nil,
            device_id: nil,
            network_name: nil,
            status: nil,
            playback: nil

  @type ip_address :: {0..255, 0..255, 0..255, 0..255}

  @type device_id :: String.t

  @type lookup_opt :: :host | :device_id | :network_name | :status | :playback
  @type lookup_opts :: [lookup_opt] | lookup_opt

  @doc """
  Starts an entity as part of a supervision tree.
  """
  @spec start_link(ip_address, Keyword.t) :: GenServer.on_start
  def start_link(addr, options \\ []) do
    GenServer.start_link(__MODULE__, addr, options)
  end

  @doc """
  Looks-up the value(s) for the given key(s).
  """
  @spec __lookup__(GenServer.server, lookup_opts) :: [term] | term
  def __lookup__(pid, keys) do
    GenServer.call(pid, {:lookup, keys})
  end

  for {fun, arity} <- MusicCast.ExtendedControl.__info__(:functions), !String.starts_with?(to_string(fun), "get_") do
    args = Enum.map(0..arity, &Macro.var(:"arg#{&1}", __MODULE__))
    @doc "See `MusicCast.ExtendedControl.#{fun}/#{arity}`."
    def unquote(fun)(unquote_splicing(args)) do
      [pid|args] = unquote(args)
      GenServer.call(pid, {:request, {unquote(fun), args}})
    end
  end

  #
  # Callbacks
  #

  def init(addr) do
    headers = [
      {"X-AppName", "MusicCast/1.50"},
      {"X-AppPort", 41100}
    ]
    with host <- to_string(:inet_parse.ntoa(addr)),
         {:ok, %{"device_id" => device_id}} <- YXC.get_device_info(host, headers: headers),
         {:ok, %{"network_name" => network_name}} <- YXC.get_network_status(host),
         {:ok, status} <- YXC.get_status(host),
         {:ok, playback} <- YXC.get_playback_info(host),
         {:ok, _} <- register_device(device_id, addr) do
      {:ok, %__MODULE__{host: host,
                        device_id: device_id,
                        network_name: network_name,
                        status: status,
                        playback: playback}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  def handle_call({:request, {fun, args}}, _from, state) do
    case apply(YXC, fun, [state.host|args]) do
      {:ok, _resp} ->
        {:reply, :ok, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:lookup, keys}, _from, state) do
    attrs = for key <- List.wrap(keys), Map.has_key?(state, key), do: Map.fetch!(state, key)
    if is_list(keys),
      do: {:reply, attrs, state},
    else: {:reply, List.first(attrs), state}
  end

  def handle_info({:unicast_event, payload}, state) do
    new_state = update_state(state, payload["main"])
    event_map = diff_state(Map.from_struct(state), Map.from_struct(new_state))
    unless map_size(event_map) == 0, do: broadcast_event(state.device_id, :update, event_map)
    {:noreply, new_state}
  end

  #
  # Helpers
  #

  defp register_device(device_id, addr) do
    Registry.register(MusicCast.Registry, device_id, addr)
  end

  defp broadcast_event(device_id, event_type, event) do
    Registry.dispatch(MusicCast.PubSub, device_id, fn subscribers ->
      for {pid, nil} <- subscribers, do: send(pid, {:extended_control, event_type, device_id, event})
    end)
  end

  defp update_state(state, %{"signal_info_updated" => true} = event) do
    state
    |> update_playback_state()
    |> update_state(Map.drop(event, ["signal_info_updated"]))
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
end
