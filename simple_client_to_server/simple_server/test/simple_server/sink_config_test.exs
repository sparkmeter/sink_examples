defmodule SimpleServer.SinkConfigTest do
  use ExUnit.Case, async: false
  alias SimpleServer.SinkConfig
  alias SimpleServer.SinkInstanceId
  alias SimpleServer.Repo
  doctest SimpleServer

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  test "init_client_instance_id" do
    s_i = Repo.get(SinkInstanceId, "self")
    assert %{client: nil, server: s_i.instance_id} == SinkConfig.get_instance_ids("dummy_client")
  end

  test "update_instance_id" do
    s_i = Repo.get(SinkInstanceId, "self")
    SinkConfig.set_client_instance_id("dummy_client", 456)

    assert %{client: 456, server: s_i.instance_id} == SinkConfig.get_instance_ids("dummy_client")
  end
end
