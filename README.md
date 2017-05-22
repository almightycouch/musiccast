# Yamaha MusicCast™

[![Travis](https://img.shields.io/travis/almightycouch/musiccast.svg)](https://travis-ci.org/almightycouch/musiccast)
[![Hex.pm](https://img.shields.io/hexpm/v/musiccast.svg)](https://hex.pm/packages/musiccast)
[![Documentation Status](https://img.shields.io/badge/docs-hexdocs-blue.svg)](http://hexdocs.pm/musiccast)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/almightycouch/musiccast/master/LICENSE)
[![Github Issues](https://img.shields.io/github/issues/almightycouch/musiccast.svg)](http://github.com/almightycouch/musiccast/issues)

![Cover image](http://imgur.com/v2E6340.jpg)

Elixir implementation of Yamaha's MusicCast™ multiroom audio solution.

## Documentation

See the [online documentation](https://hexdocs.pm/musiccast/) for more information.

## Installation

Add `:musiccast` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:musiccast, "~> 0.2"}]
end
```

## Usage

MusicCast devices are automatically discovered and added to `MusicCast.Network`, you can list all registered devices as follow:

```elixir
iex> [{pid, device_id}] = MusicCast.which_devices()
[{#PID<0.200.0>, "00A0DEDCF73E"}]
```

You can control a device using the `MusicCast.Network.Entity` module:

```elixir
iex> MusicCast.Network.Entity.set_input(pid, "spotify")
:ok
iex> MusicCast.Network.Entity.playback_play(pid)
:ok
iex> MusicCast.Network.Entity.set_volume(pid, 50)
:ok
```

You also have the possibility to subscribe to status update notifications from a specific device:

```elixir
iex> MusicCast.subscribe(device_id)
:ok
iex> flush()
{:musiccast, :update, "00A0DEDCF73E", %{playback: %{input: "spotify", playback: "pause"}}
{:musiccast, :update, "00A0DEDCF73E", %{playback: %{playback: "play"}}
{:musiccast, :update, "00A0DEDCF73E", %{status: %{volume: 50}}
```
