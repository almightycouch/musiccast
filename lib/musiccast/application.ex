defmodule MusicCast.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(MusicCast.Network, []),
      supervisor(Registry, [:duplicate, MusicCast.PubSub],   id: :pubsub),
      supervisor(Registry, [:unique,    MusicCast.Registry], id: :registry),
      server(MusicCast.UPnP.DLNA.Endpoint, [port: 4000]),
      worker(MusicCast.UPnP.SSDPClient, []),
      worker(MusicCast.Network.EventListener, [])
    ]

    opts = [strategy: :one_for_one, name: MusicCast.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp server(endpoint, options) do
    Plug.Adapters.Cowboy.child_spec(:http, endpoint, [], options)
  end
end
