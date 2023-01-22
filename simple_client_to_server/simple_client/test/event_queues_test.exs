defmodule EventQueuesTest do
  use ExUnit.Case, async: false

  @client_id "client1"
  @client_instance_id 456

  test "only one cursor manager can exist for a client_id at a time" do
    {:ok, _pid} =
      start_supervised({EventQueues.Supervisor, storage: __MODULE__, subscription: __MODULE__})

    Process.whereis(EventCursorsTest.Coordinator)

    assert :ok == EventQueues.add_client(__MODULE__, @client_id, @client_instance_id)

    assert {:error, :in_use} ==
             EventQueues.add_client(__MODULE__, @client_id, @client_instance_id)
  end

  def get_earliest_unsent_sequence_number(_, _, _), do: nil
end
