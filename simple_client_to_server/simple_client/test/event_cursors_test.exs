defmodule EventCursorsTest do
  use ExUnit.Case, async: false

  @client_id "client1"
  @client_instance_id 456

  test "only one cursor manager can exist for a client_id at a time" do
    start_supervised({EventCursors.Supervisor, storage: __MODULE__})

    assert :ok == EventCursors.add_client(:test, @client_id, @client_instance_id)

    assert {:error, :in_use} == EventCursors.add_client(:test, @client_id, @client_instance_id)
  end
end
