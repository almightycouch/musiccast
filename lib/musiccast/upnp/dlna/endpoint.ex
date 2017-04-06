defmodule MusicCast.UPnP.DLNA.Endpoint do
  @moduledoc """
  """

  use Plug.Router

  plug :match
  plug :dispatch

  get "/:filename" do
    filepath = "/Users/redrabbit/Music/iTunes/iTunes Media/Music/Guts/Freedom/01 Introducing Mr. F.m4a"
    filesize = File.stat!(filepath).size
    mimetype = MIME.from_path(filepath)

    {offset, length} = get_req_range(conn)

    conn
    |> put_resp_header("content-type", mimetype)
    |> put_resp_header("accept-ranges", "bytes")
    |> put_resp_header("content-range", "bytes #{offset}-#{length || filesize}/#{filesize}")
    |> send_file(200, filepath, offset, length || :all)
    |> Plug.Conn.halt
  end

  #
  # Helpers
  #

  defp get_req_range(conn) do
    case get_req_header(conn, "range") do
      [] ->
        {0, nil}
      ["bytes=" <> range] ->
        case String.split(range, "-") do
          [offset] ->
            {String.to_integer(offset), nil}
          [offset, length] ->
            {String.to_integer(offset), String.to_integer(length)}
        end
    end
  end
end
