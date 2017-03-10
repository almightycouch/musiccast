defmodule MusicCast.ExtendedControl do
  @moduledoc """
  A module for working with Yamaha Extended Control (YXC).

  YXC is Yamaha’s communication protocol sent over Ethernet and Wi-Fi to
  control MusicCast enabled devices.
  """

  @base_path "/YamahaExtendedControl/v1"

  @doc """
  Returns basic information for a device.
  """
  def get_device_info(host, options \\ []), do: request_api(host, "/system/getDeviceInfo", options)

  @doc """
  Returns feature information for a device.
  """
  def get_features(host, options \\ []), do: request_api(host, "/system/getFeatures", options)

  @doc """
  Returns network related information.
  """
  def get_network_status(host, options \\ []), do: request_api(host, "/system/getNetworkStatus", options)

  @doc """
  Returns information of overall system function.
  """
  def get_func_status(host, options \\ []), do: request_api(host, "/system/getFuncStatus", options)

  @doc """
  Sets auto power standby status.

  Actual operations/reactions of enabling auto power standby depend on each device.
  """
  def set_auto_power_standby(host, enable, options \\ []), do: request_api(host, "/system/setAutoPowerStandby", Keyword.put(options, :query, %{enable: enable}))

  @doc """
  Returns location information.
  """
  def get_location_info(host, options \\ []), do: request_api(host, "/system/getLocationInfo", options)

  @doc """
  Sends the given remote IR code.

  A device is operated same as remote IR code reception. But continuous IR code
  cannot be used in this command.

  Refer to each device’s IR code list for details.
  """
  def send_ir_code(host, code, options \\ []), do: request_api(host, "/system/sendIrCode", Keyword.put(options, :query, %{code: code}))

  @doc """
  Returns basic information for the given zone.
  """
  def get_status(host, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/getStatus", options)
  end

  @doc """
  Returns a list of sound program available for the given zone.
  """
  def get_sound_program_list(host, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/getSoundProgramList", options)
  end

  @doc """
  Sets power status for the given zone.
  """
  def set_power(host, power, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setPower", Keyword.put(options, :query, %{power: power}))
  end

  @doc """
  Sets sleep timer for the given zone.
  """
  def set_sleep(host, sleep, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setSleep", Keyword.put(options, :query, %{sleep: sleep}))
  end

  @doc """
  Sets volume for the given zone.
  """
  def set_volume(host, volume, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setVolume", Keyword.put(options, :query, %{volume: volume}))
  end

  @doc """
  Sets mute status for the given zone.
  """
  def set_mute(host, enable, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setMute", Keyword.put(options, :query, %{enable: enable}))
  end

  @doc """
  Selects input for the given zone.
  """
  def set_input(host, input, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setInput", Keyword.put(options, :query, %{input: input}))
  end

  @doc """
  Selects sound program for the given zone.
  """
  def set_sound_program(host, program, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/setSoundProgram", Keyword.put(options, :query, %{program: program}))
  end

  @doc """
  Prepares device before changing input for a specific zone.

  This is valid only when "prepare_input_change" exists in "func_list" found in `get_func_status/1`
  """
  def prepare_input_change(host, input, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/#{zone}/prepareInputChange", Keyword.put(options, :query, %{input: input}))
  end

  #
  # Tuner
  #

  @doc """
  Returns tuner preset information.
  """
  def get_tuner_preset_info(host, options \\ []) do
    {band, options} = Keyword.pop(options, :band, "fm")
    request_api(host, "/tuner/getPresetInfo", Keyword.put(options, :query, %{band: band}))
  end

  @doc """
  Returns tuner playback information.
  """
  def get_tuner_playback_info(host, options \\ []), do: request_api(host, "/tuner/getPlayInfo", options)

  @doc """
  Sets tuner frequency.
  """
  def set_tuner_freq(host, freq, options \\ [])
  def set_tuner_freq(host, freq, options) when is_integer(freq) do
    {band, options} = Keyword.pop(options, :band, "fm")
    request_api(host, "/tuner/setFreq", Keyword.put(options, :query, %{band: band, tuning: "direct", num: freq}))
  end

  def set_tuner_freq(host, freq, options) do
    {band, options} = Keyword.pop(options, :band, "fm")
    request_api(host, "/tuner/setFreq", Keyword.put(options, :query, %{band: band, tuning: freq}))
  end

  @doc """
  Recalls tuner preset for the given zone.
  """
  def recall_tuner_preset(host, num, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    {band, options} = Keyword.pop(options, :band, "fm")
    request_api(host, "/tuner/recallPreset", Keyword.put(options, :query, %{zone: zone, band: band, num: num}))
  end

  @doc """
  Selects tuner preset.

  Only call this API after changing the target zone’s input to tuner.
  """
  def switch_tuner_preset(host, options \\ []) do
    {dir, options} = Keyword.pop(options, :dir, "next")
    request_api(host, "/tuner/switchPreset", Keyword.put(options, :query, %{dir: dir}))
  end

  @doc """
  Stores current tuner station to a preset.
  """
  def store_tuner_preset(host, num, options \\ []), do: request_api(host, "/tuner/storePreset", Keyword.put(options, :query, %{num: num}))

  @doc """
  Sets tuner DAB service.
  """
  def set_tuner_dab_service(host, options \\ []) do
    {dir, options} = Keyword.pop(options, :dir, "next")
    request_api(host, "/tuner/setDabService", Keyword.put(options, :query, %{dir: dir}))
  end

  #
  # Network/USB
  #

  @doc """
  Returns network/usb preset information.
  """
  def get_preset_info(host, options \\ []), do: request_api(host, "/netusb/getPresetInfo", options)

  @doc """
  Returns playback information.
  """
  def get_playback_info(host, options \\ []), do: request_api(host, "/netusb/getPlayInfo", options)

  @doc """
  Sets playback status.
  """
  def set_playback(host, playback, options \\ []), do: request_api(host, "/netusb/setPlayback", Keyword.put(options, :query, %{playback: playback}))

  @doc """
  Toggles repeat setting.
  """
  def toggle_repeat(host, options \\ []), do: request_api(host, "/netusb/toggleRepeat", options)

  @doc """
  Toggles shuffle setting.
  """
  def toggle_shuffle(host, options \\ []), do: request_api(host, "/netusb/toggleShuffle", options)

  @doc """
  Returns list information.

  Basically this info is available to all relevant inputs, not limited
  to or independent from current input.
  """
  def get_list_info(host, input, options \\ []) do
    {offset, options} = Keyword.pop(options, :offset, 0)
    {limit, options} = Keyword.pop(options, :limit, 8)
    request_api(host, "/netusb/getListInfo", Keyword.put(options, :query, %{input: input, index: offset, size: limit}))
  end

  @doc """
  Executes a list control command.
  """
  def set_list_control(host, type, options \\ []), do: request_api(host, "/netusb/setListControl", Keyword.put(options, :query, %{type: type}))

  @doc """
  Search for the given string.
  """
  def set_search_string(host, search, options \\ []), do: request_api(host, "/netusb/setSearchString", Keyword.merge(options, [method: :post, query: %{string: search}]))

  @doc """
  Recalls preset for the given zone.
  """
  def recall_preset(host, num, options \\ []) do
    {zone, options} = Keyword.pop(options, :zone, "main")
    request_api(host, "/netusb/recallPreset", Keyword.put(options, :query, %{zone: zone, num: num}))
  end

  @doc """
  Stores current content to a preset.
  """
  def store_preset(host, num, options \\ []), do: request_api(host, "/netusb/storePreset", Keyword.put(options, :query, %{num: num}))

  @doc """
  Returns account information registered on a device.
  """
  def get_account_status(host, options \\ []), do: request_api(host, "/netusb/getAccountStatus", options)

  @doc """
  Returns account information registered on a device.
  """
  def switch_account(host, input, index, options \\ []), do: request_api(host, "/netusb/switchAccount", Keyword.put(options, :query, %{input: input, index: index}))

  @doc """
  Returns account information registered on a device.
  """
  def get_service_info(host, input, type, options \\ []), do: request_api(host, "/netusb/getServiceInfo", Keyword.put(options, :query, %{input: input, type: type}))

  #
  # CD
  #

  @doc """
  Returns CD playback information.
  """
  def get_cd_playback_info(host, options \\ []), do: request_api(host, "/cd/getPlayInfo", options)

  @doc """
  Sets CD playback status.
  """
  def set_cd_playback(host, playback, options \\ []), do: request_api(host, "/cd/setPlayback", Keyword.put(options, :query, %{playback: playback}))

  @doc """
  Toggles CD tray setting.
  """
  def toggle_cd_tray(host, options \\ []), do: request_api(host, "/cd/toggleTray", options)

  @doc """
  Toggles CD repeat setting.
  """
  def toggle_cd_repeat(host, options \\ []), do: request_api(host, "/cd/toggleRepeat", options)

  @doc """
  Toggles CD shuffle setting.
  """
  def toggle_cd_shuffle(host, options \\ []), do: request_api(host, "/cd/toggleShuffle", options)


  #
  # Helpers
  #

  defp request_api(host, path, options) do
    {method, options}    = Keyword.pop(options, :method, :get)
    {base_path, options} = Keyword.pop(options, :base_path, @base_path)

    case HTTPoison.request(method, host <> base_path <> path, options) do
      {:ok, %HTTPoison.Response{body: body, status_code: status}} when status in 200..299 ->
        with {:ok, response} <- Poison.decode(body),
             {:ok, response} <- process_response_code(response), do:
          {:ok, response}
      {:ok, %HTTPoison.Response{}} ->
        {:error, :invalid_response}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp process_response_code(%{"response_code" => 0} = response) do
    {:ok, response}
  end

  defp process_response_code(%{"response_code" => response_code}) do
     case response_code do
         1 -> {:error, :initializing}
         2 -> {:error, :internal_error}
         3 -> {:error, :invalid_request}
         4 -> {:error, :invalid_parameter}
         5 -> {:error, :guarded}
         6 -> {:error, :time_out}
        99 -> {:error, :firmware_updating}
       100 -> {:error, :access_error}
       101 -> {:error, :streaming_error}
       102 -> {:error, :wrong_username}
       103 -> {:error, :wrong_password}
       104 -> {:error, :account_expired}
       105 -> {:error, :account_disconnected}
       106 -> {:error, :account_limit_reached}
       107 -> {:error, :server_maintenance}
       108 -> {:error, :invalid_account}
       109 -> {:error, :license_error}
       110 -> {:error, :read_only_mode}
       111 -> {:error, :max_stations}
       112 -> {:error, :access_denied}
       _   -> {:error, :unknown_error}
     end
  end
end
