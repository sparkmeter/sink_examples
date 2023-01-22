defmodule SimpleClient.SinkHandler do
  @moduledoc """
  Hooks to handle connection setup events that come across the connection.

  For connection setup, Sink needs to know the instance_id of the client and if a
  server instance_id has been set. After a connection is established, a connection
  response of `:connected` will be received.

  During normal connection a client may receieve a publish event from the server or
  an ack or a nack for a publish the client sent to the server.
  """
  require Logger
  use Ecto.Schema
  alias SimpleClient.SinkConfig
  alias SimpleClient.OutgoingEventSubscription
  @behaviour Sink.Connection.ClientConnectionHandler

  @impl true
  def handle_connection_response(:connected) do
    Logger.info("Connected to known server via Sink")

    EventCursors.add_client(OutgoingEventSubscription, "self", "self")

    :ok
  end

  @impl true
  def handle_connection_response({:hello_new_client, instance_id}) do
    Logger.info("Connected to server via Sink for the first time")

    :ok = SinkConfig.set_server_instance_id(instance_id)

    EventCursors.add_client(OutgoingEventSubscription, "self", "self")
  end

  def handle_connection_response(response) do
    Logger.info("Failed to connect with with #{inspect(response)}")

    :ok
  end

  @impl true
  def down do
    Logger.info("Disconnected from server via Sink")

    EventCursors.remove_client(OutgoingEventSubscription, "self")

    :ok
  end

  @impl true
  def application_version do
    Application.spec(:simple_client, :vsn) |> to_string()
  end

  @impl true
  def instance_ids do
    SinkConfig.get_instance_ids()
  end

  @impl true
  def handle_publish(sink_event, _message_id) do
    # In this example only the client is sending messages, so we don't expect the server
    # to send us anything.
    Logger.error("Server sent us a message??? #{inspect(sink_event)}")

    {:nack, <<>>, "This example only sends from client to server"}
  end

  @impl true
  def handle_ack(ack_key) do
    Logger.info("received 'ack' for event: #{inspect(ack_key)}")

    sequence_number = nil
    SimpleClient.ack_event(ack_key, sequence_number)

    :ok
  end

  @impl true
  def handle_nack(ack_key, {machine_message, human_message}) do
    Logger.warn(
      "Received a nack on '#{inspect(ack_key)}', with '#{inspect({machine_message, human_message})}'"
    )

    :ok
  end
end
