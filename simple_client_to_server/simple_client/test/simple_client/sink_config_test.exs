defmodule SimpleClient.SinkConfigTest do
  use ExUnit.Case, async: false
  alias SimpleClient.SinkConfig
  alias SimpleClient.Repo
  doctest SimpleClient

  setup do
    # Explicitly get a connection before each test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  test "init_client_instance_id" do
    SinkConfig.init_client_instance_id()
    assert %{client: _client_id, server: nil} = SinkConfig.get_instance_ids()
  end

  test "update_instance_id" do
    # todo: move setup to factory?
    SinkConfig.init_client_instance_id()

    SinkConfig.set_server_instance_id(12345)

    assert %{client: _client_id, server: 12345} = SinkConfig.get_instance_ids()
  end
end
