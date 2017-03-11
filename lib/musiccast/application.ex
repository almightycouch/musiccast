defmodule MusicCast.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(MusicCast.Network, []),
      supervisor(Registry, [:unique, MusicCast.Registry]),
      worker(MusicCast.SSDPClient, []),
      worker(MusicCast.Network.EventListener, []),
    ]

    opts = [strategy: :one_for_one, name: MusicCast.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
