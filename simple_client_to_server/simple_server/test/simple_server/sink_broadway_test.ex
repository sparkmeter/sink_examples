defmodule SimpleServer.SinkBroadwayTest do
  use ExUnit.Case, async: false
  alias SimpleServer.SinkConfig
  alias SinkBroadway.ProducerTracker
  doctest SimpleServer

  @now DateTime.utc_now()
  @client_id "client1"
  @client_instance_id 456
  @sample_event %Sink.Event{
    event_type_id: 1,
    key: <<1, 2, 3>>,
    offset: 1,
    schema_version: 2,
    timestamp: DateTime.to_unix(@now),
    event_data:
      :erlang.term_to_binary(%{
        temperature: 70,
        humidity: 40
      })
  }

  test "receiving an event triggers the incoming event processor" do
    {:ok, _} = SinkConfig.set_client_instance_id(@client_id, @client_instance_id)
    client = {@client_id, @client_instance_id}

    :ok = ProducerTracker.add_client(client)

    :ack = SimpleServer.SinkHandler.handle_publish(@client_id, @sample_event, 12345)

    :timer.sleep(10)
    assert nil != ProducerTracker.max_ingested_at(client)

    # todo: assert the event was processed

    assert true
  end
end
