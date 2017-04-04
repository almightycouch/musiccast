# Yamaha MusicCast™

[![Travis](https://img.shields.io/travis/almightycouch/musiccast.svg)](https://travis-ci.org/almightycouch/musiccast)
[![Hex.pm](https://img.shields.io/hexpm/v/musiccast.svg)](https://hex.pm/packages/musiccast)
[![Documentation Status](https://img.shields.io/badge/docs-hexdocs-blue.svg)](http://hexdocs.pm/musiccast)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/almightycouch/musiccast/master/LICENSE)
[![Github Issues](https://img.shields.io/github/issues/almightycouch/musiccast.svg)](http://github.com/almightycouch/musiccast/issues)

Elixir implementation of Yamaha's MusicCast™ multiroom audio solution.

## Documentation

See the [online documentation](https://hexdocs.pm/musiccast/) for more information.

## Installation

Add `:musiccast` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:musiccast, "~> 0.1"}]
end
```

## Usage

Start by discovering MusicCast devices on your network:

```elixir
:ok = MusicCast.discover()
```

Devices are automatically added to `MusicCast.Network`, you can list all registered devices as follow:

```elixir
[{pid, device_id}] = MusicCast.which_devices()
```

You can control a device using the `MusicCast.Network.Entity` module:

```elixir
:ok = MusicCast.Network.Entity.set_volume(pid, 50)
:ok = MusicCast.Network.Entity.set_playback(pid, "pause")
```

You also have the possibility to subscribe to notifications from a specific device:

```elixir
:ok = MusicCast.subscribe(device_id)
```
