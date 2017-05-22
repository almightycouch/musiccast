defmodule MusicCast.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(MusicCast.Network, []),
      supervisor(Registry, [:duplicate, MusicCast.PubSub],   id: :pubsub),
      supervisor(Registry, [:unique,    MusicCast.Registry], id: :registry),
      worker(MusicCast.Network.EventDispatcher, []),
      worker(MusicCast.UPnP.SSDPClient, [])
    ]

    opts = [strategy: :one_for_one, name: MusicCast.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
