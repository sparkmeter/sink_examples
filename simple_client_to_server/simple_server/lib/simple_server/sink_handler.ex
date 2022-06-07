defmodule SimpleServer.SinkHandler do
  @moduledoc """
  Handle events that come across the connection
  """
  require Logger
  @behaviour Sink.Connection.ServerConnectionHandler

  @impl true
  def up(client_id) do
    Logger.info("Connected to client #{client_id} via Sink")

    :ok
  end

  @impl true
  def down(client_id) do
    Logger.info("Disconnected from client #{client_id} via Sink")

    :ok
  end

  @impl true
  def authenticate_client(cert) do
    {:ok, "fake"}
  end

  @impl true
  def handle_publish(client_id, sink_event, _message_id) do
    Logger.info("received an event from client #{client_id}, #{inspect(sink_event)}")

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

  defp authenticated_clients do
    %{
      "todo: insert cert here" => "simple_client_1"
    }
  end
end
