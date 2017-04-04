defmodule MusicCast.UPnP.AVTransport do
  @moduledoc """
  Defines a “common” model for A/V transport control suitable for a UPnP generic user interface.
  """

  use MusicCast.UPnP.Service,
    type: "AVTransport:1",
    desc: "avtransport.xml"
end
