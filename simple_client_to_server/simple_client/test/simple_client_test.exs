defmodule SimpleClientTest do
  use ExUnit.Case, async: false
  alias SimpleClient.{GroundEventLog, LastSensorReading}
  alias SimpleClient.Repo
  doctest SimpleClient

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

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

  describe "get_next_queued_event" do
    test "is empty with no events" do
      assert nil == SimpleClient.get_next_event()
    end

    test "returns the next event when events are present" do
      SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
      SimpleClient.log_sensor_reading("kitchen", %{temperature: 71, humidity: 41})

      next_event = SimpleClient.get_next_event()
      assert nil != next_event
      assert "kitchen" == next_event.key
      assert 1 == next_event.offset
    end

    test "does not return ack'd events" do
      {:ok, _} = SimpleClient.log_sensor_reading("kitchen", %{temperature: 70, humidity: 40})
      next = SimpleClient.get_next_event()
      {:ok, _} = SimpleClient.ack_event({next.event_type_id, next.key, next.offset})

      assert nil == SimpleClient.get_next_event()
    end
  end
end
