options = [generate: :server,
           generate_tests: :none,
           automatic_prefixes: true,
           http_client: :soap_client_inets,
           http_server: :soap_server_inets]


File.cd!("priv")

:soap.wsdl2erlang('upnp_av.wsdl', options)

File.mkdir!("../src")
File.mkdir!("../include")

File.rename("upnp_av_server.erl", "../src/upnp_av_server.erl"
File.rename("upnp_av.hrl", "../include/upnp_av.hrl"
File.cd!("..")
