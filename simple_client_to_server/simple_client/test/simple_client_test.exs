defmodule SimpleClientTest do
  use ExUnit.Case, async: false
  alias SimpleClient.{GroundEventLog, LastSensorReading}
  alias SimpleClient.Repo
  alias SimpleClient.OutgoingEventSubscription
  doctest SimpleClient

  @client_id "self"
  @client_instance_id "123"

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Setting the shared mode must be done only after checkout
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    :ok
  end

  test "log_sensor_reading" do
    SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
    SimpleClient.log_sensor_reading("kitchen", %{temperature: 71, humidity: 41})
    SimpleClient.log_sensor_reading("bedroom", %{temperature: 65, humidity: 45})

    events = Repo.all(LastSensorReading)
    assert 2 == length(events)

    events = Repo.all(GroundEventLog)
    assert 3 == length(events)
  end

  describe "get_next_event" do
    setup do
      {:ok, _} =
        start_supervised({EventCursors.Supervisor, storage: SimpleClient.SinkSubscriptionStorage})

      :ok
    end

    test "is empty with no events" do
      :ok = EventCursors.add_client(OutgoingEventSubscription, @client_id, @client_instance_id)

      assert nil == SimpleClient.get_next_event()
    end

    test "returns the next event when events are present" do
      :ok = EventCursors.add_client(OutgoingEventSubscription, @client_id, @client_instance_id)

      SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
      SimpleClient.log_sensor_reading("kitchen", %{temperature: 71, humidity: 41})

      next_event = SimpleClient.get_next_event()
      assert nil != next_event
      assert "kitchen" == next_event.key
      assert 1 == next_event.offset

      next_event = SimpleClient.get_next_event()
      assert nil != next_event
      assert "kitchen" == next_event.key
      assert 2 == next_event.offset

      assert nil == SimpleClient.get_next_event()
    end

    test "does not return ack'd events" do
      {:ok, _} = SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
      bogus_seq_number = 1
      :ok = SimpleClient.ack_event({1, "kitchen", 1}, bogus_seq_number)

      :ok = EventCursors.add_client(OutgoingEventSubscription, @client_id, @client_instance_id)

      assert nil == SimpleClient.get_next_event()
    end

    test "retries a NACK when starting the client is added" do
      {:ok, _} = SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
      {:ok, _} = SimpleClient.log_sensor_reading("kitchen", %{temperature: 71, humidity: 41})
      bogus_seq_number = 1
      :ok = SimpleClient.nack_event({1, "kitchen", 1}, bogus_seq_number)

      :ok = EventCursors.add_client(OutgoingEventSubscription, @client_id, @client_instance_id)

      next_event = SimpleClient.get_next_event()
      assert nil != next_event
      assert "kitchen" == next_event.key
      assert 1 == next_event.offset

      assert nil == SimpleClient.get_next_event()
    end
  end
end
