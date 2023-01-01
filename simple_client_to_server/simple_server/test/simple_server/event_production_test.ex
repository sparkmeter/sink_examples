defmodule SimpleServer.EventProductionTest do
  use ExUnit.Case, async: false
  alias SimpleServer.SinkConfig
  doctest SimpleServer

  @now DateTime.utc_now()
  @client_id "client1"
  @client_instance_id 456
  @sample_event %Sink.Event{
    event_type_id: 1,
    key: <<1, 2, 3>>,
    offset: 3,
    schema_version: 2,
    timestamp: DateTime.to_unix(@now),
    event_data:
      :erlang.term_to_binary(%{
        temperature: 70,
        humidity: 40
      })
  }

  test "a received event is tracked by the CacheManager" do
    {:ok, _} = SinkConfig.set_client_instance_id(@client_id, @client_instance_id)

    assert :ok = EventProduction.add_client(@client_id, @client_instance_id)

    :ack = SimpleServer.SinkHandler.handle_publish(@client_id, @sample_event, 12345)

    # make sure pub sub has time to do its thing
    :timer.sleep(10)

    assert 0 < EventProduction.max_sequence_number(@client_id)

    assert 3 !=
             EventProduction.max_offset(
               @client_id,
               {@sample_event.event_type_id, @sample_event.key}
             )
  end

  test "only one producer tracker can listen on a client-instance_id at a time" do
    {:ok, _} = SinkConfig.set_client_instance_id(@client_id, @client_instance_id)

    assert :ok == EventProduction.add_client(@client_id, @client_instance_id)

    assert {:error, :in_use} == EventProduction.add_client(@client_id, @client_instance_id)
  end
end
