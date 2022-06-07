defmodule SimpleClient.SinkHandler do
  @moduledoc """
  Handle events that come across the connection
  """
  require Logger
  use Ecto.Schema
  @behaviour Sink.Connection.ClientConnectionHandler

  @impl true
  def up do
    Logger.info("Connected to server via Sink")

    :ok
  end

  @impl true
  def down do
    Logger.info("Disconnected from server via Sink")

    :ok
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

    SimpleClient.ack_event(ack_key)

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
