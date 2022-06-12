# Simple Client to Server

This is a simple example of a client that generates some data, connects to a Sink server, and transmits the data. The point is to demonstrate how Sink reliably synchronizes data between two locations. An Elixir application exists for the client (`simple_client`) and the server (`simple_server`).

The client has sensors that measure temperature and humidity of a room. It transmits these to the server (when they are connected) and the server outputs the data in its logs.

## The Client

Readings are logged with `SimpleClient.log_sensor_reading` and stored in a SQLite database. Every few seconds a process polls the database for readings to send to the server. It will send those readings via the Sink connection and record an acknowledgement when it receives it from the server.

The poller (`OutgoingEventPoller`) operates about as simply as possible: events are transmitted in the order they were logged in the event log (`GroundEventLog`). When an event is ACK'd, a record is inserted in the `AckLog`. The sequence of events is then:

* The client logs zero or many events (sensor readings).
* If the client is connected to the server, the poller queries the database for events which have not been acknowledged.
* If the poller finds unacknowledged events it will send Sink `PUBLISH` events to the server in the order the events were logged.
* When the server receives these events it sends an `ACK` over the Sink connection for each received event.
* When the client receives the `ACK` it inserts a record in the `AckLog`. This is how the poller know not to resend the event.
* The process repeats.

## The Server

The server handles authentication of clients and only logs the sensor reading to `Logger.info`.

## How To Run the Example

Open up two terminal windows, one for `simple_client`, one for `simple_server`. You could start them in either order, but for demonstration purposes we'll start the client first.

### Setup

First install the dependencies and run the migrations for the client:
```
mix deps.get
mix ecto.migrate
```

Then install the dependencies for the server:
```
mix deps.get
```

### Start the client

In your terminal: `simple_client $ iex -S mix`

In the client iex shell:
```elixir
# show that the client is not connected
iex> Sink.Connection.Client.connected?
false

# generate some sample readings
iex> SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
{:ok, %SimpleClient.LastSensorReading{...}}}
iex> SimpleClient.log_sensor_reading("kitchen", %{temperature: 71, humidity: 39})
{:ok, %SimpleClient.LastSensorReading{...}}}
iex> SimpleClient.log_sensor_reading("bedroom", %{temperature: 68, humidity: 35})
{:ok, %SimpleClient.LastSensorReading{...}}}

# check the queue size
iex> SimpleClient.queue_size
3

# check the next queued event
iex> SimpleClient.get_next_event()
%Sink.Event{...}
```

### Stop the client
In the client iex shell:
```elixir
> System.halt # or <ctrl-c>
```

### Start the server

`simple_server $ iex -S mix`

```elixir
# show that the client is not connected
iex> Sink.Connection.ServerHandler.connected?("example-client")
false
```

### Connect the client so it can send readings

Start the client again. Once it connects it will automatically start sending events. It make take a few seconds to transmit all the events since the poller only sends once per second.
```elixir
iex> Sink.Connection.Client.connected?
true

# check the queue size
iex> SimpleClient.queue_size
0

# check the next queued event
iex> SimpleClient.get_next_event()
nil
```

## What Might Be Different in the Real World?

* As the client accumulates more readings it may run out of space or queries may take longer because the tables have many entries. You would use a retention policy and clean-up process to manage deleting old events.
* The client has to know what sensors it has. This would come either from the server (after someone adds the sensors in a cloud web UI) or locally (if the client detects the sensors or has a local web UI). This will likely be covered in another example.
* The "key" for a sensor would be a unique integer or uuid instead of a name.
* SSL keypairs would not be in source control.
* Sending events in the order they were created makes for a simple system (which is good!), but if the event fails to transmit then synchronization stops. Your system may have several independent streams of data (ex: readings, telemetry data, configuration data, etc.) and a failure in one of these streams / channels. doesn't need to stop synchronization of other streams / channels.
* The poller could be more advanced. Ex: Sink allows for more than 1 message in flight, but the poller here only sends 1 event at a time. Also, dynamically adjusting polling frequency based on number of items in the queue.
* Sqlite cannot handle concurrent writes. In this case `SimpleClient.log_sensor_reading` and `SimpleClient.ack_event` both write to the database so it's possible (especially under load) that the two would try to write at the same time. This can best be managed by single-threading writes.
* Maybe you don't want to use SQLite. That's fine.