defmodule SimpleServer.EventProductionTest do
  use ExUnit.Case, async: false
  alias SimpleServer.SinkConfig
  alias EventProduction.EventProducer
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

    assert :ok = EventProduction.Coordinator.add_client(:incoming_event, @client_id)

    :ack = SimpleServer.SinkHandler.handle_publish(@client_id, @sample_event, 12345)

    # make sure pub sub has time to do its thing
    :timer.sleep(10)

    assert nil != EventProducer.max_ingested_at(:incoming_event, @client_id)

    assert nil !=
             EventProducer.max_offset(
               :incoming_event,
               @client_id,
               {@sample_event.event_type_id, @sample_event.key}
             )

    assert nil != EventProducer.produce_events(:incoming_event, @client_id)

    assert true
  end

  test "only one producer tracker can listen on a client-instance_id at a time" do
    {:ok, _} = SinkConfig.set_client_instance_id(@client_id, @client_instance_id)

    assert :ok == EventProduction.Coordinator.add_client(:incoming_event, @client_id)

    assert {:error, :in_use} ==
             EventProduction.Coordinator.add_client(:incoming_event, @client_id)
  end
end
