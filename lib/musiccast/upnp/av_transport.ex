defmodule MusicCast.UPnP.AVTransport do
  use MusicCast.UPnP.Service,
    urn: "urn:schemas-upnp-org:service:AVTransport:1",
    url: "http://192.168.0.63:49154/AVTransport/desc.xml"
end
