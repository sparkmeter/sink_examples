# SimpleClient

This is a simple example of how to make a client that generates some data, connects to a Sink server, and transmits the data.

## How To Run the Example

(optional) Start your Simple Sink Server in another window (see example here: (todo: do this))

Start IEx

`iex -S mix`

Check that the client is connected (if the server is running)

```elixir
> Sink.Connection.Client.connected?
true
```

Generate some sample readings
```
> SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
```

Check that the client sent the readings to the server

todo: implement this.
```elixir
> SimpleClient.queue_size
```