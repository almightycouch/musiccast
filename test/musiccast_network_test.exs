defmodule MusicCastNetworkTest do
  use ExUnit.Case, async: true

  @ip_addresses []

  alias MusicCast.Network
  alias MusicCast.Network.Entity
  alias MusicCast.ExtendedControl, as: YXC

  setup_all do
    MusicCast.discover()
    Process.sleep(1_000)
  end

  test "network discovery" do
    disco = Process.whereis(MusicCast.UPnP.SSDPClient)
    state = :sys.get_state(disco)
    count = Enum.count(Enum.filter(state.entities, &is_reference(elem(&1, 1))))
    assert count == length(@ip_addresses)
  end

  test "network consistency" do
    count = Enum.count(Supervisor.which_children(Network))
    assert count == length(@ip_addresses)
    Enum.each(Network.which_devices(), fn
      {pid, device_id} ->
        assert {^pid,  addr} = Network.whereis(device_id)
        assert addr in @ip_addresses
    end)
  end

  test "compares devices state and result of api requests" do
    Enum.each(Network.which_devices([:host, :device_id, :network_name, :status, :playback]), fn
      {_pid, host, device_id, network_name, status, playback} ->
        assert {:ok, %{"device_id" => ^device_id}} = YXC.get_device_info(host)
        assert {:ok, %{"network_name" => ^network_name}} = YXC.get_network_status(host)
        assert {:ok, ^status} = YXC.get_status(host)
        assert {:ok, ^playback} = YXC.get_playback_info(host)
    end)
  end

  test "fails to add an already registered device to the network" do
    Enum.each(@ip_addresses, fn
      addr ->
        assert {:error, {:already_registered, pid}} = Network.add_device(addr)
        assert Entity.__lookup__(pid, :host) == to_string(:inet_parse.ntoa(addr))
    end)
  end
end
