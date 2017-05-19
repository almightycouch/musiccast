defmodule MusicCast.UPnP.Plug.EventDispatcher do
  @moduledoc """
  A `Plug` for receiving and dispatching incoming UPnP events.

  ## Example

      scope "/upnp", MusicCast.UPnP.Plug do
        forward "/event", EventDispatcher, service: MusicCast.UPnP.AVTransport
      end
  """

  alias MusicCast.UPnP.Service

  import Plug.Conn


  @behaviour Plug

  @spec init(Plug.opts) :: Plug.opts
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Plug.opts) :: Plug.Conn.t
  def call(conn, opts) do
    service = Keyword.fetch!(opts, :service)
    [session_id] = get_req_header(conn, "sid")
    {:ok, body, conn} = read_body(conn)
    event = Service.parse_event(service, body)
    dispatch_event(session_id, event)
    send_resp(conn, 200, "")
  end

  #
  # Helpers
  #

  defp dispatch_event(session_id, event) do
    devices = MusicCast.which_devices(:upnp_session_id)
    if pid = Enum.find_value(devices, &match_device(session_id, &1)) do
      send(pid, {:upnp_event, event})
    end
  end

  defp match_device(session_id, {pid, device_session_id}) when session_id == device_session_id, do: pid
  defp match_device(_session_id, _lookup), do: nil
end
