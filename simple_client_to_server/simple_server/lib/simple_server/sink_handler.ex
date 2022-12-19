defmodule SimpleServer.SinkHandler do
  @moduledoc """
  Handle events that come across the connection
  """
  require Logger
  alias SimpleServer.SinkConfig
  alias SinkBroadway.ProducerTracker
  @behaviour Sink.Connection.ServerConnectionHandler

  @authenticated_clients SimpleServer.load_authenticated_clients()

  @impl true
  def supported_application_version?(_client_id, _version) do
    # here is where you would check which application versions are supported
    true
  end

  @impl true
  def client_configuration(client_id) do
    SinkConfig.client_configuration(client_id)
  end

  @impl true
  def handle_connection_response(client_id, :connected) do
    IO.puts("connection resp")
    Logger.info("Connected to known client #{client_id} via Sink")

    :ok
  end

  def handle_connection_response(client_id, {:hello_new_client, client_instance_id}) do
    Logger.info("Connected to new client #{client_id} via Sink")
    {:ok, _} = SinkConfig.set_client_instance_id(client_id, client_instance_id)

    :ok
  end

  def handle_connection_response(client_id, response) do
    Logger.debug(
      "Server rejected connection request with #{inspect(response)} for client #{client_id}"
    )

    :ok
  end

  @impl true
  def down(client_id) do
    Logger.info("Disconnected from client #{client_id} via Sink")

    :ok
  end

  @impl true
  def authenticate_client(cert) do
    case @authenticated_clients[cert] do
      nil ->
        {:error, "Unknown client"}

      client_id ->
        {:ok, client_id}
    end
  end

  @impl true
  def handle_publish(client_id, sink_event, _message_id) do
    Logger.info("received an event from client #{client_id}, #{inspect_event(sink_event)}")

    ingested_at = DateTime.utc_now()
    instance_id = get_instance_id(client_id)
    client = {client_id, instance_id}
    {:ok, _} = SimpleServer.insert_ground_event(client, sink_event, ingested_at)

    Phoenix.PubSub.broadcast(
      :sink_events,
      "#{client_id}-#{instance_id}:#{sink_event.event_type_id}",
      {:publish, {client_id, instance_id}, sink_event, ingested_at}
    )

    Phoenix.PubSub.broadcast(
      :sink_events,
      ProducerTracker.topic(client),
      {:publish, {client_id, instance_id}, sink_event, ingested_at}
    )

    :ack
  end

  @impl true
  def handle_ack(client_id, ack_key) do
    # In this example only the client is sending events, so we don't expect the server
    # to be receiving ACKs (since it isn't publishing events).
    Logger.error("Client #{client_id} sent us an ACK??? #{inspect(ack_key)}")

    :ok
  end

  @impl true
  def handle_nack(client_id, ack_key, {machine_message, human_message}) do
    # We don't expect any NACKs either, since the server isn't sending any events
    Logger.error(
      "Client #{client_id} sent us a NACK??? '#{inspect(ack_key)}', with '#{inspect({machine_message, human_message})}'"
    )

    :ok
  end

  defp inspect_event(%Sink.Event{event_type_id: 1, schema_version: 1} = sink_event) do
    data = :erlang.binary_to_term(sink_event.event_data)
    "sensor: #{sink_event.key}, timestamp: #{sink_event.timestamp}, data: #{inspect(data)}"
  end

  defp get_instance_id(client_id) do
    # This is a hack
    # todo: figure out better way to manage this, probably pass it to handle_publish via Sink
    s_i = SimpleServer.Repo.get(SimpleServer.SinkInstanceId, client_id)
    s_i.instance_id
  end
end
